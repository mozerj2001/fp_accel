`timescale 1ns / 1ps

`include "../sources_1/tanimoto_top.v"

module tb_tanimoto_top #(
)(
);

    localparam BUS_WIDTH          = 128;
    localparam BUS_WIDTH_BYTES    = BUS_WIDTH/8;
    localparam VECTOR_WIDTH       = 920;
    localparam VECTOR_WIDTH_BYTES = 115;
    localparam SUB_VECTOR_NO      = 8;
    localparam REF_VEC_NO         = 8;
    localparam CMP_VEC_NO         = 24;

    localparam BUS_WIDTH_r          = $itor(BUS_WIDTH         );
    localparam BUS_WIDTH_BYTES_r    = $itor(BUS_WIDTH_BYTES   );
    localparam VECTOR_WIDTH_r       = $itor(VECTOR_WIDTH      );
    localparam VECTOR_WIDTH_BYTES_r = $itor(VECTOR_WIDTH_BYTES);
    localparam SUB_VECTOR_NO_r      = $itor(SUB_VECTOR_NO     );
    localparam REF_VEC_NO_r         = $itor(REF_VEC_NO        );
    localparam CMP_VEC_NO_r         = $itor(CMP_VEC_NO        );

    localparam NUM_REF_BUS_CYCLES = $rtoi(((REF_VEC_NO_r*VECTOR_WIDTH_BYTES_r) + BUS_WIDTH_BYTES_r - 1)*8 / BUS_WIDTH_r);
    localparam NUM_CMP_BUS_CYCLES = $rtoi(((CMP_VEC_NO_r*VECTOR_WIDTH_BYTES_r) + BUS_WIDTH_BYTES_r - 1)*8 / BUS_WIDTH_r);

    localparam GRANULE_WIDTH    = 6;
    localparam VEC_ID_WIDTH     = 8;
    localparam CNT_WIDTH        = $clog2(VECTOR_WIDTH);

    localparam SHR_DEPTH        = REF_VEC_NO;

    localparam CLK_PERIOD       = 10;
    localparam HALF_CLK_PERIOD  = CLK_PERIOD/2;

    reg clk                         = 1'b0;
    reg rstn                        = 1'b0;
    wire cmp_rdy;

    reg [CNT_WIDTH:0]   threshold = 0;
    reg [CNT_WIDTH-1:0] threshold_addr = 0;
    reg                 wr_threshold;

    reg input_last = 0;


    // TEST FIFO SIGNALS
    reg [BUS_WIDTH-1:0] f_din   = {BUS_WIDTH{1'b0}};
    wire f_read;
    wire [BUS_WIDTH-1:0] f_dout;
    wire f_full;
    wire f_empty;

    // TEST FIFO
    srl_fifo
    #(
        .WIDTH  (BUS_WIDTH                                  ),
        .DEPTH  ((REF_VEC_NO + CMP_VEC_NO) * SUB_VECTOR_NO  )
    ) test_fifo (
        .clk    (clk            ),
        .rstn   (rstn           ),
        .wr     (f_write        ),
        .d      (f_din          ),
        .full   (f_full         ),
        .rd     (f_read         ),
        .q      (f_dout         ),
        .empty  (f_empty        )
    );


    // DUT
    wire                        id_pair_read;
    wire [2*VEC_ID_WIDTH-1:0]   id_pair_out;
    wire                        id_pair_last;
    wire                        id_pair_ready;

    assign id_pair_read = id_pair_ready;

    top_intf #(
        .BUS_WIDTH       (BUS_WIDTH     ),
        .VECTOR_WIDTH    (VECTOR_WIDTH  ),
        .SHR_DEPTH       (SHR_DEPTH     ),
        //
        .SUB_VECTOR_NO   (SUB_VECTOR_NO ),
        .GRANULE_WIDTH   (GRANULE_WIDTH ),
        .VEC_ID_WIDTH    (VEC_ID_WIDTH  )
    ) dut (
        .ap_clk                 (clk                ),
        .ap_rstn                (rstn               ),
        .S_AXIS_DATA_tdata      (f_dout             ),
        .S_AXIS_DATA_tvalid     (~f_empty && state  ),
        .S_AXIS_DATA_tlast      (input_last         ),
        .S_AXIS_DATA_tready     (f_read             ),
        .M_AXIS_ID_PAIR_tdata   (id_pair_out        ),
        .M_AXIS_ID_PAIR_tvalid  (id_pair_ready      ),
        .M_AXIS_ID_PAIR_tlast   (id_pair_last       ),
        .M_AXIS_ID_PAIR_tready  (id_pair_read       ),
        .BRAM_PORTA_clk_a       (clk                ),
        .BRAM_PORTA_rst_a       (!rstn              ),  
        .BRAM_PORTA_addr_a      (threshold_addr     ),
        .BRAM_PORTA_wrdata_a    (threshold          ), 
        .BRAM_PORTA_rddata_a    (                   ), 
        .BRAM_PORTA_en_a        (1'b1               ),  
        .BRAM_PORTA_we_a        (wr_threshold       )
    );

    always begin 
        clk <= ~clk;
        #HALF_CLK_PERIOD;
    end

    reg state = 0;
    reg [31:0] vec_cntr = 0;
    reg [1:0] sparsity_cntr = 0;
    reg sparse_traffic_test = 1;
    wire input_valid = sparse_traffic_test ? (sparsity_cntr == 2'b11) : 1'b1;

    always @ (posedge clk)
    begin
        sparsity_cntr <= sparsity_cntr + 1;
    end

    always @ (posedge clk)
    begin
        if(f_read && ~f_empty) begin
            vec_cntr <= vec_cntr + 1;
        end

        if(vec_cntr == (NUM_REF_BUS_CYCLES+NUM_CMP_BUS_CYCLES-1)) begin
            input_last <= 1'b1;
        end else begin
            input_last <= 1'b0;
        end

        if(vec_cntr == (NUM_REF_BUS_CYCLES + NUM_CMP_BUS_CYCLES)) begin
            state <= 1'b0;
        end

        if(id_pair_ready && id_pair_read) begin
            $fwrite(id_file, "%x\t%x\n",
                id_pair_out[2*VEC_ID_WIDTH-1:VEC_ID_WIDTH], id_pair_out[VEC_ID_WIDTH-1:0]);
        end
    end

    integer id_file;
    initial begin
        id_file = $fopen("results.bin", "wb");
        wait(id_pair_last == 1'b1);
        $fclose(id_file);
    end

    // STIMULUS
    // load threshold RAM and vectors
    integer vector_file;
    integer scan_file;
    reg [7:0] vectors [(REF_VEC_NO+CMP_VEC_NO)*VECTOR_WIDTH_BYTES-1:0];
    real THRESHOLD = 0.66;

    initial begin
        // Read vectors from binary file
        vector_file = $fopen("vectors.bin", "rb");
        
        if (vector_file == 0) begin
            $display("Error: Could not open vectors.bin");
            $finish;
        end
        
        scan_file = $fread(vectors, vector_file);
        if (scan_file == 0) begin
            $display("Error: Failed to read vectors from vectors.bin!");
            $finish;
        end else begin
            $display("Info: fread returned %d\n", scan_file);
        end
        
        $fclose(vector_file);

        // Load threshold RAM with pre-calculated data
        #50;
        rstn <= 1'b1;
        #10;
        #CLK_PERIOD;
        wr_threshold <= 1;
        for(integer cnt_c = 0; cnt_c <= VECTOR_WIDTH; cnt_c = cnt_c + 1) begin
            threshold = $rtoi(cnt_c * (2.0-THRESHOLD)/(1.0-THRESHOLD));
            threshold_addr = cnt_c;
            #CLK_PERIOD;
        end
        wr_threshold <= 0;
        #CLK_PERIOD;
        state = 1'b1;
    end

    // fill FIFOs
    reg f_write;
    always @ (posedge clk)
    begin
        if(!rstn || !state) begin
            f_write <= 0;
        end else begin
            if(input_valid) begin
                f_write <= 1'b1;
            end else begin
                f_write <= 1'b0;
            end
        end
    end

    // Feed vectors to FIFO
    integer ii, jj;
    always @ (posedge clk)
    begin
        if(rstn && state && input_valid) begin
            ii = vec_cntr;
            for(jj = 0; jj < BUS_WIDTH_BYTES; jj = jj + 1) begin
                if(ii*BUS_WIDTH_BYTES + jj < scan_file) begin
                    f_din[jj*8 +: 8] <= vectors[ii*BUS_WIDTH_BYTES + jj];
                end else begin
                    f_din[jj*8 +: 8] <= 8'h0;
                end
            end
        end
    end

    initial begin
        #100;
        rstn <= 1'b1;
    end

endmodule

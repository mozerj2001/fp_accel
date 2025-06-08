`timescale 1ns / 1ps

`include "../sources_1/srl_fifo.v"
`include "../sources_1/vec_cat.v"

module tb_vec_cat(

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

    reg clk = 1'b0;
    reg rstn = 1'b0;
    reg [BUS_WIDTH-1:0] vector;
    reg valid = 1'b0;
    wire [VEC_ID_WIDTH-1:0] vec_id;
    wire [BUS_WIDTH-1:0] cat_vector;
    wire cat_valid;
    wire cat_last;
    reg  cat_ready = 1'b1;

    // FIFO SIGNALS
    reg [BUS_WIDTH-1:0] f_din   = {BUS_WIDTH{1'b0}};
    wire f_read;
    wire [BUS_WIDTH-1:0] f_dout;
    wire f_full;
    wire f_empty;

    reg input_last = 0;

    reg f_write_d;
    always @ (posedge clk)
    begin
        f_write_d <= !state;
    end

    // TEST FIFO
    srl_fifo
    #(
        .WIDTH  (BUS_WIDTH      ),
        .DEPTH  (VECTOR_WIDTH   )
    ) test_fifo (
        .clk    (clk        ),
        .rstn   (rstn       ),
        .wr     (f_write_d  ),
        .d      (f_din      ),
        .full   (f_full     ),
        .rd     (f_read     ),
        .q      (f_dout     ),
        .empty  (f_empty    )
    );


    // DUT
    vec_cat
    #(
        .BUS_WIDTH      (BUS_WIDTH      ),
        .VECTOR_WIDTH   (VECTOR_WIDTH   ),
        .VEC_ID_WIDTH   (VEC_ID_WIDTH   )
    ) dut(
        .clk        (clk                                    ),
        .rstn       (rstn                                   ),
        .up_Vector  (f_dout                                 ),
        .up_Valid   ((~f_empty && state)                    ),
        .up_Last    (input_last                             ),
        .up_Ready   (f_read                                 ),
        .dn_Vector  (cat_vector                             ),
        .dn_VecID   (vec_id                                 ),
        .dn_Valid   (cat_valid                              ),
        .dn_Last    (cat_last                               ),
        .dn_Ready   (cat_ready                              )
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
    end

    // STIMULUS
    // load threshold RAM and vectors
    integer vector_file;
    integer scan_file;
    reg [7:0] vectors [(REF_VEC_NO+CMP_VEC_NO)*VECTOR_WIDTH_BYTES-1:0];

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

    // RESET
    initial begin
        #100;
        rstn <= 1'b1;
        #100;
        state <= 1'b1;
        #30000;
        $finish;
    end


endmodule

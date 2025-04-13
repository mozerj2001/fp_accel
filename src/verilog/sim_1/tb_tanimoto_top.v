`timescale 1ns / 1ps

`include "../sources_1/tanimoto_top.v"

module tb_tanimoto_top(

    );

    localparam BUS_WIDTH          = 128;
    localparam BUS_WIDTH_BYTES    = BUS_WIDTH/8;
    localparam VECTOR_WIDTH       = 920;
    localparam VECTOR_WIDTH_BYTES = 115;
    localparam SUB_VECTOR_NO      = 8;
    localparam REF_VEC_NO         = 8;
    localparam CMP_VEC_NO         = 128;

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
    localparam VEC_ID_WIDTH     = $clog2(VECTOR_WIDTH);
    localparam CNT_WIDTH        = $clog2(VECTOR_WIDTH);

    localparam SHR_DEPTH        = REF_VEC_NO;

    localparam CLK_PERIOD       = 10;
    localparam HALF_CLK_PERIOD  = CLK_PERIOD/2;

    reg clk                         = 1'b0;
    reg rstn                        = 1'b0;
    reg [BUS_WIDTH-1:0] vector;
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

    tanimoto_top
    #(
        .BUS_WIDTH      (BUS_WIDTH      ),
        .VECTOR_WIDTH   (VECTOR_WIDTH   ),
        .SUB_VECTOR_NO  (SUB_VECTOR_NO  ),
        .GRANULE_WIDTH  (GRANULE_WIDTH  ),
        .SHR_DEPTH      (SHR_DEPTH      ),
        .VEC_ID_WIDTH   (VEC_ID_WIDTH   )
    ) dut (
        .clk                    (clk                ),
        .rstn                   (rstn               ),
        .i_Vector               (f_dout             ),
        .i_Valid                (~f_empty && state  ),
        .i_Last                 (input_last         ),
        .i_BRAM_Addr            (threshold_addr     ),
        .i_BRAM_Din             (threshold          ),
        .i_BRAM_En              (1'b1               ),
        .i_BRAM_WrEn            (wr_threshold       ),
        .i_IDPair_Read          (id_pair_read       ),
        .o_Read                 (f_read             ),
        .o_IDPair_Ready         (id_pair_ready      ),
        .o_IDPair_Out           (id_pair_out        ),
        .o_IDPair_Last          (id_pair_last       )
    );

    always begin 
        clk <= ~clk;
        #HALF_CLK_PERIOD;
    end

    reg state = 0;
    reg [31:0] vec_cntr = 0;
    reg [1:0] sparsity_cntr = 0;
    wire input_valid = (sparsity_cntr == 2'b11);

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
    // load threshold RAM
    initial begin
        #50;
        rstn <= 1'b1;
        #10;
        #CLK_PERIOD;
        wr_threshold <= 1;
        for(integer i = 0; i < VECTOR_WIDTH; i = i + 1) begin
            threshold = threshold + 1;
            threshold_addr = threshold_addr + 1;
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

    // generate random input vectors
    integer ii;
    always @ (posedge clk)
    begin
        if(rstn && state && input_valid) begin
            for(ii = 0; ii*32 < VECTOR_WIDTH; ii = ii + 1) begin
                f_din[ii*32 +: 32] <= $urandom();
            end
        end
    end


    initial begin
        #100;
        rstn <= 1'b1;
    end

endmodule

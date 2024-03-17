`timescale 1ns / 1ps

`include "../../sources_1/new/top_cnt1.v"

module tb_top_cnt1(

    );

    localparam BUS_WIDTH        = 96;
    localparam VECTOR_WIDTH     = 128;
    localparam SUB_VECTOR_NO    = 2;
    localparam GRANULE_WIDTH    = 6;
    localparam SHR_DEPTH        = 32;
    localparam VEC_ID_WIDTH     = $clog2(VECTOR_WIDTH);
    localparam CNT_WIDTH        = $clog2(VECTOR_WIDTH);


    localparam CLK_PERIOD       = 10;
    localparam HALF_CLK_PERIOD  = CLK_PERIOD/2;

    reg clk                     = 1'b0;
    reg rst                     = 1'b1;
    reg [BUS_WIDTH-1:0] vector;
    reg wr_threshold            = 0;
    wire cmp_rdy;

    reg [CNT_WIDTH-1:0] threshold = 25;


    // TEST FIFO SIGNALS
    reg f_write                 = 1'b0;
    reg [BUS_WIDTH-1:0] f_din   = {BUS_WIDTH{1'b0}};
    wire f_read;
    wire [BUS_WIDTH-1:0] f_dout;
    wire f_full;
    wire f_empty;


    // TEST FIFO
    srl_fifo
    #(
        .WIDTH  (BUS_WIDTH      ),
        .DEPTH  (VECTOR_WIDTH   )
    ) test_fifo (
        .clk    (clk            ),
        .rst    (rst            ),
        .wr     (f_write_d      ),
        .d      (f_din          ),
        .full   (f_full         ),
        .rd     (f_read         ),
        .q      (f_dout         ),
        .empty  (f_empty        )
    );


    // DUT
    wire                        id_pair_read;
    wire [2*VEC_ID_WIDTH-1:0]   id_pair_out;
    wire                        id_pair_ready;

    assign id_pair_read = id_pair_ready;

    top_cnt1
    #(
        .BUS_WIDTH      (BUS_WIDTH      ),
        .VECTOR_WIDTH   (VECTOR_WIDTH   ),
        .SUB_VECTOR_NO  (SUB_VECTOR_NO  ),
        .GRANULE_WIDTH  (GRANULE_WIDTH  ),
        .SHR_DEPTH      (SHR_DEPTH      ),
        .VEC_ID_WIDTH   (VEC_ID_WIDTH   )
    ) dut (
        .clk                    (clk            ),
        .rst                    (rst            ),
        .i_Vector               (f_dout         ),
        .i_Valid                (~f_empty       ),
        .i_WrThreshold          (wr_threshold   ),
        .i_Threshold            (threshold      ),
        .i_IDPair_Read          (id_pair_read   ),
        .o_Read                 (f_read         ),
        .o_ComparatorsReady     (cmp_rdy        ),
        .o_IDPair_Ready         (id_pair_ready  ),
        .o_IDPair_Out           (id_pair_out    )
    );

    always begin 
        clk <= ~clk;
        #HALF_CLK_PERIOD;
    end


    // FILL FIFOS
    integer fp_vec;
    integer scan;
    reg [BUS_WIDTH-1:0] vec;
    initial begin
        fp_vec = $fopen("/home/jozmoz01/Documents/fp_accel/project_1.srcs/sources_1/new/test_vectors.dat", "r");
        if(fp_vec == 0) begin
            $display("File containing test vectors was not found...");
            $finish;
        end
    end

    reg f_write_d;
    always @ (posedge clk)
    begin
        if(rst) begin
            f_write_d <= 0;
        end else begin
            f_write_d <= f_write;
        end
    end

    always @ (posedge clk)
    begin
        if(~rst & f_write) begin
            scan = $fscanf(fp_vec, "%h\n", vec);
            if(!$feof(fp_vec)) begin
                f_din <= vec;
            end
        end
    end


    initial begin
        #100;
        rst <= 1'b0;
        #CLK_PERIOD;
        wr_threshold <= 1'b1;
        #CLK_PERIOD;
        wr_threshold <= 1'b0;
        #500;
        f_write <= 1'b1;
        if($feof(fp_vec)) begin
            f_write <= 1'b0;
        end
        #CLK_PERIOD;
    end


endmodule

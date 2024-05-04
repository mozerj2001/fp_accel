`timescale 1ns / 1ps
`default_nettype none

`include "../sources_1/comparator_wrapper.v"


module tb_comparator_wrapper(

    );

    localparam VECTOR_WIDTH     = 35;
    localparam BUS_WIDTH        = 20;
    localparam CNT_WIDTH        = $clog2(VECTOR_WIDTH);

    localparam CLK_PERIOD       = 10;
    localparam HALF_CLK_PERIOD  = CLK_PERIOD/2;

    localparam LOAD_RAM         = 1'b0;
    localparam DUT_TEST         = 1'b1;
    localparam THRESHOLD        = 24;


    //
    reg rst = 1;
    reg clk = 0;

    reg [CNT_WIDTH-1:0] cnt_a = 0;
    reg [CNT_WIDTH-1:0] cnt_b = 0;
    reg [CNT_WIDTH-1:0] cnt_c = 0;

    reg [CNT_WIDTH-1:0] threshold       = 25;
    reg                 wr_threshold    = 0;
    reg                 valid           = 0;

    wire out_valid;
    wire ready;
    wire dout;

    // testbench state machine
    reg state = LOAD_RAM;

    // DUT
    comparator_wrapper #(
        .VECTOR_WIDTH   (VECTOR_WIDTH   ),
        .BUS_WIDTH      (BUS_WIDTH      )
    ) u_dut (
        .clk            (clk            ),
        .rst            (rst            ),
        .i_CntA         (cnt_a          ),
        .i_CntB         (cnt_b          ),
        .i_CntC         (cnt_c          ),
        .i_WrThreshold  (wr_threshold   ),
        .i_Threshold    (threshold      ),
        .i_Valid        (valid          ),
        .o_Valid        (out_valid      ),
        .o_Ready        (ready          ),
        .o_Dout         (dout           )          // 1: over threshold, 0: under threshold
    );

    // clk gen
    always begin 
        clk <= ~clk;
        #HALF_CLK_PERIOD;
    end


    initial begin
        #10;
        rst <= 1'b0;
        #500;
        wr_threshold <= 1'b1;
        #CLK_PERIOD;
        wr_threshold <= 1'b0;
        #550;
        wr_threshold <= 1'b1;
        #CLK_PERIOD;
        wr_threshold <= 1'b0;
    end


    initial begin
        #2000;
        #CLK_PERIOD;
        valid <= 1'b1;
        cnt_a <= 33;
        cnt_b <= 17;
        cnt_c <= 17;
        #CLK_PERIOD;
        cnt_a <= 8;
        cnt_b <= 19;
        cnt_c <= 6;
        #CLK_PERIOD;
        cnt_a <= 15;
        cnt_b <= 32;
        cnt_c <= 12;
        #CLK_PERIOD;
        cnt_a <= 35;
        cnt_b <= 17;
        cnt_c <= 17;
        #CLK_PERIOD;
        cnt_a <= 8;
        cnt_b <= 5;
        cnt_c <= 1;
        #CLK_PERIOD;
        cnt_a <= 35;
        cnt_b <= 35;
        cnt_c <= 35;
        #CLK_PERIOD;
        cnt_a <= 24;
        cnt_b <= 0;
        cnt_c <= 0;
        #CLK_PERIOD;
        cnt_a <= 0;
        cnt_b <= 0;
        cnt_c <= 0;
        #CLK_PERIOD;
        valid <= 1'b0;
        #500;
        #CLK_PERIOD;
        cnt_a <= 33;
        cnt_b <= 17;
        cnt_c <= 17;
        #CLK_PERIOD;
        valid <= 1'b1;
        cnt_a <= 8;
        cnt_b <= 19;
        cnt_c <= 6;
        #CLK_PERIOD;
        cnt_a <= 15;
        cnt_b <= 32;
        cnt_c <= 12;
        #CLK_PERIOD;
        cnt_a <= 35;
        cnt_b <= 17;
        cnt_c <= 17;
        #CLK_PERIOD;
        cnt_a <= 8;
        cnt_b <= 5;
        cnt_c <= 1;
        #CLK_PERIOD;
        cnt_a <= 35;
        cnt_b <= 35;
        cnt_c <= 35;
        #CLK_PERIOD;
        cnt_a <= 24;
        cnt_b <= 0;
        cnt_c <= 0;
        #CLK_PERIOD;
        cnt_a <= 0;
        cnt_b <= 0;
        cnt_c <= 0;
        #CLK_PERIOD;
        valid <= 1'b0;
    end



endmodule




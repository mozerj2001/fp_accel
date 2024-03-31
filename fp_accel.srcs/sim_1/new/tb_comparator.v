`timescale 1ns / 1ps
`default_nettype none

`include "../../sources_1/new/comparator.v"


module tb_comparator(

    );

    localparam VECTOR_WIDTH    = 35;
    localparam BUS_WIDTH       = 20;
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

    reg [CNT_WIDTH-1:0] threshold       = 30;
    reg [CNT_WIDTH:0]   wr_threshold    = 0;

    wire dout;

    // testbench state machine
    reg state = LOAD_RAM;

    srl_fifo#(
    ) u_ext_fifo (
    );


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
        .o_Dout         (dout           )
    );

    // clk gen
    always begin 
        clk <= ~clk;
        #HALF_CLK_PERIOD;
    end

    // stimulus


    initial begin
        #50;
        rst <= 1'b0;
        wr_threshold <= 1'b1;
        #CLK_PERIOD;
        wr_threshold <= 1'b0;
    end

    initial begin
        #500;
        #CLK_PERIOD;
        cnt_a = 33;
        cnt_b = 17;
        cnt_c = 17;
        #CLK_PERIOD;
        cnt_a = 8;
        cnt_b = 19;
        cnt_c = 6;
        #CLK_PERIOD;
        cnt_a = 15;
        cnt_b = 32;
        cnt_c = 12;
        #CLK_PERIOD;
        cnt_a = 35;
        cnt_b = 17;
        cnt_c = 17;
        #CLK_PERIOD;
        cnt_a = 8;
        cnt_b = 5;
        cnt_c = 1;
        #CLK_PERIOD;
        cnt_a = 35;
        cnt_b = 35;
        cnt_c = 35;
        #CLK_PERIOD;
        cnt_a = 24;
        cnt_b = 0;
        cnt_c = 0;
        #CLK_PERIOD;
        cnt_a = 0;
        cnt_b = 0;
        cnt_c = 0;
    end



endmodule


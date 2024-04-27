`timescale 1ns / 1ps
`default_nettype none

`include "../../sources_1/new/bit_cntr_wrapper.v"

module tb_bit_cntr_wrapper(

    );

    // TEST PARAMETERS
    localparam CLK_PERIOD = 10;
    localparam HALF_CLK_PERIOD = 5;
    localparam T_RESET = 30;

    localparam VECTOR_WIDTH = 160;
    localparam GRANULE_WIDTH = 6;
    localparam OUTPUT_WIDTH = 16; 

    // UUT
    reg clk = 0;
    reg rst = 1;
    reg [VECTOR_WIDTH-1:0] test_Vector = 160'b0;
    reg test_Valid;
    reg test_LastWordOfVector;
    wire [OUTPUT_WIDTH-1:0] test_Sum;
    wire test_SumValid;
    wire test_SumNew;

    bit_cntr_wrapper
    #(
        .VECTOR_WIDTH(VECTOR_WIDTH), 
        .GRANULE_WIDTH(GRANULE_WIDTH),
        .OUTPUT_WIDTH(OUTPUT_WIDTH)
    )
    uut(
        .clk(clk),
        .rst(rst),
        .i_Vector(test_Vector),
        .i_Valid(test_Valid),
        .i_LastWordOfVector(test_LastWordOfVector),

        .o_Sum(test_Sum),
        .o_SumValid(test_SumValid),
        .o_SumNew(test_SumNew)        // o_Sum can be read
    );

    // STIMULUS
    always
    begin
        clk <= ~clk;
        #HALF_CLK_PERIOD;
    end

    initial
    begin
        #T_RESET;
        rst <= 1'b0;
        test_Vector <= 160'h0000000000000000000000000000000000000000;
        test_Valid <= 1'b0;
        test_LastWordOfVector <= 1'b0;

        #(CLK_PERIOD * 10);

        test_Valid <= 1'b1;
        test_Vector <= 160'h0000000000000000000000000000000000000000;   // 0

        #CLK_PERIOD;

        test_Vector <= 160'hFFFFFFFF00000000FFFFFFFF00000000FFFFFFFF;   // 96
        test_LastWordOfVector <= 1'b1;

        // sum = 96

        #CLK_PERIOD;

        test_LastWordOfVector <= 1'b0;
        test_Vector <= 160'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;   // 160

        #CLK_PERIOD;

        test_LastWordOfVector <= 1'b1;
        test_Vector <= 160'h1111111111111111111111111111111111111111;   // 40

        // sum = 200

        #CLK_PERIOD;

        test_LastWordOfVector <= 1'b0;
        test_Vector <= 160'h3333333333333333333333333333333333333333;   // 80

        #CLK_PERIOD;

        test_Vector <= 160'h7777777777777777777777777777777777777777;   // 120
        test_LastWordOfVector <= 1'b1;

        // sum = 200

        #CLK_PERIOD;

        test_LastWordOfVector <= 1'b0;
        test_Vector <= 160'h0000000000000000000000000000000000000000;   // 0

        #CLK_PERIOD;

        test_LastWordOfVector <= 1'b1;
        test_Vector <= 160'h0000000000000000000000000000000000000000;   // 0

        // sum = 0

        #CLK_PERIOD;

        test_LastWordOfVector <= 1'b0;
        test_Vector <= 160'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;   // 160

        #CLK_PERIOD;

        test_Vector <= 160'hEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE;   // 120
        test_LastWordOfVector <= 1'b1;

        // sum = 280

        #CLK_PERIOD;

        test_LastWordOfVector <= 1'b0;
        test_Vector <= 160'h5555555555555555555555555555555555555555;   // 80

        #CLK_PERIOD;

        test_LastWordOfVector <= 1'b1;
        test_Vector <= 160'h1111111111111111111111111111111111111111;   // 40

        // sum = 120

        #CLK_PERIOD;
        test_LastWordOfVector <= 1'b0;
        test_Valid <= 1'b0;
    end



endmodule

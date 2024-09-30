`timescale 1ns / 1ps
`default_nettype none

`include "../sources_1/cnt1.v"

// Testbench for the pre-stage unit.

module tb_cnt1(

    );

    // TEST PARAMETERS
    localparam CLK_PERIOD = 10;
    localparam HALF_CLK_PERIOD = 5;
    localparam T_RESET = 30;

    localparam BUS_WIDTH = 128;
    localparam SUB_VECTOR_NO = 2;
    localparam GRANULE_WIDTH = 6;
    localparam OUTPUT_VECTOR_WIDTH = BUS_WIDTH*SUB_VECTOR_NO;
    localparam BIT_NO_OUTPUT_WIDTH = $clog2(OUTPUT_VECTOR_WIDTH);

    // UUT
    reg                            clk = 0;
    reg                            rstn = 0;
    reg [BUS_WIDTH-1:0]            test_Vector;
    reg                            test_Valid;
    wire [BUS_WIDTH-1:0]           o_SubVector;
    wire [BIT_NO_OUTPUT_WIDTH-1:0] o_Cnt;

    cnt1#(
        .BUS_WIDTH(BUS_WIDTH),
        .SUB_VECTOR_NO(SUB_VECTOR_NO),
        .GRANULE_WIDTH(GRANULE_WIDTH)
    )
    uut(
        .clk(clk),
        .rstn(rstn),
        .i_Vector(test_Vector),
        .i_Valid(test_Valid),
        .o_SubVector(o_SubVector),
        .o_Cnt(o_Cnt)
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
        rstn <= 1'b1;
        test_Vector <= 128'h00000000000000000000000000000000;
        test_Valid <= 1'b0;

        #(CLK_PERIOD * 10);

        test_Valid <= 1'b1;
        test_Vector <= 128'h11111111111111111111111111111111;   // 32
        #CLK_PERIOD;
        test_Vector <= 128'hFFFFFFFF00000000FFFFFFFF00000000;   // 64
        #CLK_PERIOD;
        // sum = 96

        test_Vector <= 128'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;   // 128
        #CLK_PERIOD;
        test_Vector <= 128'h11111111111111111111111111111111;   // 32
        // sum = 160

        #CLK_PERIOD;
        test_Vector <= 128'h33333333333333333333333333333333;   // 64
        #CLK_PERIOD;
        test_Vector <= 128'h77777777777777777777777777777777;   // 96
        // sum = 160

        #CLK_PERIOD;
        test_Vector <= 128'h00000000000000000000000000000000;   // 0
        #CLK_PERIOD;
        test_Vector <= 128'h00000000000000000000000000000000;   // 0
        // sum = 0

        #CLK_PERIOD;
        test_Vector <= 128'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;   // 128
        #CLK_PERIOD;
        test_Vector <= 128'hEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE;   // 96
        // sum = 224

        #CLK_PERIOD;
        test_Vector <= 128'h55555555555555555555555555555555;   // 64
        #CLK_PERIOD;
        test_Vector <= 128'h11111111111111111111111111111111;   // 32
        // sum = 96

        #CLK_PERIOD;
        test_Vector <= 128'hF0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0;   // 64
        #CLK_PERIOD;
        test_Vector <= 128'hE070E070E070E070E070E070E070E070;   // 48
        // sum = 112

        #CLK_PERIOD;
        test_Vector <= 128'h12341234123412341234123412341234;   // 40
        #CLK_PERIOD;
        test_Vector <= 128'h11111111111111111111111111111111;   // 32
        // sum = 72
        
        #CLK_PERIOD;
        test_Vector <= 128'h00000000000000000000000000000000;   // 0
        #CLK_PERIOD;
        test_Vector <= 128'hFFFFFFFF00000000FFFFFFFF00000000;   // 64
        // sum = 64

        #CLK_PERIOD;
        test_Vector <= 128'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;   // 128
        #CLK_PERIOD;
        test_Vector <= 128'h11111111111111111111111111111111;   // 32
        // sum = 160

        #CLK_PERIOD;
        test_Vector <= 128'h33333333333333333333333333333333;   // 64
        #CLK_PERIOD;
        test_Vector <= 128'h77777777777777777777777777777777;   // 96
        // sum = 160

        #CLK_PERIOD;
        test_Vector <= 128'h00000000000000000000000000000000;   // 0
        #CLK_PERIOD;
        test_Vector <= 128'h00000000000000000000000000000000;   // 0
        // sum = 0

        #CLK_PERIOD;
        test_Vector <= 128'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;   // 128
        #CLK_PERIOD;
        test_Vector <= 128'hEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE;   // 96
        // sum = 224

        #CLK_PERIOD;
        test_Vector <= 128'h55555555555555555555555555555555;   // 64
        #CLK_PERIOD;
        test_Vector <= 128'h11111111111111111111111111111111;   // 32
        // sum = 96

        #CLK_PERIOD;
        test_Vector <= 128'hF0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0;   // 64
        #CLK_PERIOD;
        test_Vector <= 128'hE070E070E070E070E070E070E070E070;   // 48
        // sum = 112

        #CLK_PERIOD;
        test_Vector <= 128'h12341234123412341234123412341234;   // 40
        #CLK_PERIOD;
        test_Vector <= 128'h11111111111111111111111111111111;   // 32
        // sum = 72
        //
        #CLK_PERIOD;
        test_Valid <= 1'b0;
    end


endmodule

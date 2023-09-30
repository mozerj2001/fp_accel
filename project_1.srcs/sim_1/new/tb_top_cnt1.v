`timescale 1ns / 1ps
`default_nettype none

module tb_top_cnt1(

    );

    localparam BUS_WIDTH = 20;
    localparam VECTOR_WIDTH = 35;
    localparam SUB_VECTOR_NO = 2;
    localparam GRANULE_WIDTH = 6;
    localparam SHR_DEPTH = 4;

    localparam CLK_PERIOD = 10;
    localparam HALF_CLK_PERIOD = CLK_PERIOD/2;

    reg clk = 1'b0;
    reg rst = 1'b1;
    reg [BUS_WIDTH-1:0] vector;
    reg valid = 1'b0;
    reg AB_sel;
    reg do_calc;

    wire [$clog2(VECTOR_WIDTH)-1:0] cnt_A;
    wire [$clog2(VECTOR_WIDTH)-1:0] cnt_B;
    wire [$clog2(VECTOR_WIDTH)-1:0] cnt_AB;
    wire valid_out;


    top_cnt1
    #(
        .BUS_WIDTH(BUS_WIDTH),
        .VECTOR_WIDTH(VECTOR_WIDTH),
        .SUB_VECTOR_NO(SUB_VECTOR_NO),
	.GRANULE_WIDTH(GRANULE_WIDTH),
	.SHR_DEPTH(SHR_DEPTH)
    ) uut(
    .clk(clk),
    .rst(rst),
    .i_Vector(vector),
    .i_Valid(valid),
    .i_AB_Sel(AB_sel),
    .i_Do_Calc(do_calc),
    .o_CntA(cnt_A),
    .o_CntB(cnt_B),
    .o_CntAnB(cnt_AB),
    .o_Valid(valid_out)

    );

    always begin 
        clk <= ~clk;
        #HALF_CLK_PERIOD;
    end

    initial begin
        #50;
        valid <= 1'b1;
        rst <= 1'b0;
        vector <= 20'b11111111111111111111;
        #CLK_PERIOD;
        vector <= 20'b11111111111111100110;
        #CLK_PERIOD;
        vector <= 20'b01100110011001100110;
        #CLK_PERIOD;
        vector <= 20'b01100110011111111111;
        #CLK_PERIOD;
        vector <= 20'b11111111111111111111;
        #CLK_PERIOD;
        vector <= 20'b11111010101010101010;
        #CLK_PERIOD;
        vector <= 20'b10101010101010101010;
        #CLK_PERIOD;
        vector <= 20'b11111111111111111111;
        #CLK_PERIOD;
        //valid <= 1'b0;
    end


endmodule

`timescale 1ns / 1ps
`default_nettype none

module tb_vec_cat(

    );

    localparam BUS_WIDTH = 20;
    localparam VECT_WIDTH = 35;
    localparam CAT_REG_NO = 4;

    localparam CLK_PERIOD = 10;
    localparam HALF_CLK_PERIOD = CLK_PERIOD/2;

    reg clk = 1'b0;
    reg rst = 1'b1;
    reg [BUS_WIDTH-1:0] vector;
    reg valid = 1'b0;
    wire [BUS_WIDTH-1:0] cat_vector;
    wire cat_valid;

    vec_cat
    #(
        .BUS_WIDTH(BUS_WIDTH),
        .VECT_WIDTH(VECT_WIDTH),
        .CAT_REG_NO(CAT_REG_NO)
    ) uut(
    .clk(clk),
    .rst(rst),
    .i_Vector(vector),
    .i_Valid(valid),
    .o_Vector(cat_vector),
    .o_Valid(cat_valid)
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
        valid <= 1'b0;
    end


endmodule

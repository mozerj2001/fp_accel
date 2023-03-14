`timescale 1ns / 1ps
`default_nettype none

// This is a testbench file for the parametrizable bit counter.

module tb_bit_cntr(

    );

    localparam CLK_PERIOD = 10;
    localparam HALF_CLK_PERIOD = 5;
    localparam VECTOR_WIDTH = 54;
    localparam PIPELINE_DEPTH = 2;
    localparam NO_OF_ADDERS = 5;

    reg clk = 0;
    reg rst;
    reg [VECTOR_WIDTH-1:0] vector;
    wire [(PIPELINE_DEPTH+1)*2:0] sum;

    bit_cntr
    #(
        .VECTOR_WIDTH(VECTOR_WIDTH),
        .PIPELINE_DEPTH(PIPELINE_DEPTH),
        .NO_OF_ADDERS(NO_OF_ADDERS)
    )
    uut(
        .clk(clk),
        .rst(rst),
        .i_Vector(vector),
        .sum(sum)
    );

    // STIMULUS
    always
    begin
        clk <= ~clk;
        #HALF_CLK_PERIOD;
    end

    initial
    begin
        rst <= 1;
        vector <= 24'hFFFFFF;
        #CLK_PERIOD rst <= 0;

        #CLK_PERIOD vector <= 54'h0F0F0F0F0F0F0F;
        #CLK_PERIOD vector <= 54'h06666666666666;
        #CLK_PERIOD vector <= 54'h01111111111111;
        #CLK_PERIOD vector <= 54'h0FFFFFFFFFFFFF;
    end

endmodule

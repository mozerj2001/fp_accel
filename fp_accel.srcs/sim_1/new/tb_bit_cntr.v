`timescale 1ns / 1ps
`default_nettype none

// This is a testbench file for the parametrizable bit counter.

module tb_bit_cntr(

    );

    localparam CLK_PERIOD = 10;
    localparam HALF_CLK_PERIOD = 5;
    localparam VECTOR_WIDTH = 50;
    localparam GRANULE_WIDTH = 6;
    localparam GW3 = 3*GRANULE_WIDTH;
    localparam PIPELINE_DEPTH = $clog2(VECTOR_WIDTH/GW3)/$clog2(3);
    localparam NO_OF_ADDERS = 4;

    reg clk = 0;
    reg rst;
    reg [VECTOR_WIDTH-1:0] vector;
    wire [(PIPELINE_DEPTH+1)*2:0] sum;

    bit_cntr
    #(
        .VECTOR_WIDTH(VECTOR_WIDTH),
        .GRANULE_WIDTH(GRANULE_WIDTH),
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
        vector <= 50'h0FFFFFFFFFFFF;
        #CLK_PERIOD rst <= 0;

        #CLK_PERIOD vector <= 50'h0F0F0F0F0F0F0;
        #CLK_PERIOD vector <= 50'h0666666666666;
        #CLK_PERIOD vector <= 50'h0111111111111;
        #CLK_PERIOD vector <= 50'h0FFFFFFFFFFFF;
    end

endmodule

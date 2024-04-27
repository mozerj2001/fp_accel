`timescale 1ns / 1ps
`default_nettype none

// This is a testbench file for the parametrizable bit adder.


module tb_bit_adder(

    );

    localparam GRANULE_WIDTH = 6;

    reg [GRANULE_WIDTH-1:0] r_TestVector;
    wire [GRANULE_WIDTH/2-1:0] w_Sum;

    bit_adder
    #(  .VECTOR_WIDTH(GRANULE_WIDTH) )
    uut(
        .i_Vector(r_TestVector),
        .o_Sum(w_Sum)
    );


    initial
    begin
        #100;
        r_TestVector <= 6'b101010;
        #100;
        r_TestVector <= 6'b111111;
        #100;
        r_TestVector <= 6'b110110;
        #100;
        r_TestVector <= 6'b001001;
        #100;
        r_TestVector <= 6'b000000;
    end

endmodule

`timescale 1ns / 1ps
`default_nettype none

// This is a parametrizable adder, the output of which is the number of
// high bits in the input vector.

module bit_adder
    #(
        parameter VECTOR_WIDTH = 6              // how wide the input vector is
    )
    (
        input wire [VECTOR_WIDTH-1:0]           i_Vector,
        output reg [VECTOR_WIDTH/2-1:0]         o_Sum
    );

    integer ii;
    always @ (i_Vector) begin
        o_Sum = 0;
        for(ii = 0; ii < VECTOR_WIDTH; ii = ii + 1) begin
            o_Sum = o_Sum + i_Vector[ii];
        end
    end

endmodule

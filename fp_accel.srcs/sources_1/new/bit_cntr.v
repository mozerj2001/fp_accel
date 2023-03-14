`timescale 1ns / 1ps
`default_nettype none

// This is a parametrizable bit counter, that counts the number of bits with
// the value '1' in the input vector.
// Assumption: 6-bit LUTs and 3 input adders.

module bit_cntr
    #(
        parameter VECTOR_WIDTH = 920,
        parameter PIPELINE_DEPTH = 4,           //log3(VECTOR_WIDTH/18)
        parameter NO_OF_ADDERS = 40
    )
    (
        input wire                      clk,
        input wire                      rst,
        input wire [VECTOR_WIDTH-1:0]   i_Vector,

        output wire [(PIPELINE_DEPTH-1)*2:0] sum 
    );

    localparam EXT_VECTOR_WIDTH = VECTOR_WIDTH + (18 - (VECTOR_WIDTH % 18));

    // PAD INPUT VECTOR
    // Pad the input vector to be divisible by eighteen (6*3).
    wire [EXT_VECTOR_WIDTH-1:0] w_ExtendedVector;
    assign w_ExtendedVector = {i_Vector, {(18 - (VECTOR_WIDTH % 18)){1'b0}}};


    // PIPELINE PRE-STAGE
    // Create sum of bits in every 6-bit slice of the current input vector.
    // Assign the result to the corresponding three bits of the 6BitSum
    // register.
    integer ii = 0;
    reg [VECTOR_WIDTH/2-1:0] r_6BitSum;

    always @ (posedge clk)
    begin
        for(ii = 0; ii < (VECTOR_WIDTH/6); ii = ii+1)
        begin
            if(rst)
                r_6BitSum[3*ii+:3] <= 3'b0;
            else
                r_6BitSum[3*ii+:3] <=   i_Vector[ii*6]      + 
                                        i_Vector[ii*6+1]    + 
                                        i_Vector[ii*6+2]    + 
                                        i_Vector[ii*6+3]    + 
                                        i_Vector[ii*6+4]    + 
                                        i_Vector[ii*6+5];
        end
    end

    // PIPELINE STAGE 1-N
    // Add three of the results from the previous stage in every stage.
    // The pipeline itself is an array of registers of appropriate sizing.
    integer jj = 0;
    integer kk = 0;
    reg [NO_OF_ADDERS-1:0] pipeline [(PIPELINE_DEPTH+1)*2:0];

    always @ (posedge clk)
    begin
        for(jj = 0; jj <= NO_OF_ADDERS; jj = jj + 1) begin
            if(jj >= (NO_OF_ADDERS-3**(PIPELINE_DEPTH-1))) begin
                kk = jj - (NO_OF_ADDERS-3**(PIPELINE_DEPTH-1));
                pipeline[jj] <= r_6BitSum[3*kk+:3];
            end
            else begin
                pipeline[jj] <= pipeline[3*jj+1] + pipeline[3*jj+2] + pipeline[3*jj+3];
            end
        end
    end

    assign sum = pipeline[0];

endmodule

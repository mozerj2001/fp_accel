`timescale 1ns / 1ps
`default_nettype none

// This is a parametrizable bit counter, that counts the number of bits with
// the value '1' in the input vector. It operates based on the principle of
// binary adder trees.

module bit_cntr
    #(
        parameter VECTOR_WIDTH = 920,           // how wide the input vector is
        parameter GRANULE_WIDTH = 6             // how many bits are summed in stage 1
    )
    (
        input wire                      clk,
        input wire                      rst,
        input wire [VECTOR_WIDTH-1:0]   i_Vector,

        output wire [$clog2(VECTOR_WIDTH):0] o_Sum 
    );


    // how many bits per first stage adder?
    localparam GW3 = GRANULE_WIDTH*3;
    // how many r_Pipeline stages? ($clog3(VECTOR_WIDTH))
    localparam PIPELINE_DEPTH = $clog2(VECTOR_WIDTH/GW3)/$clog2(3)+1;
    // how wide is the padded vector?
    localparam EXT_VECTOR_WIDTH = 3**(PIPELINE_DEPTH) * GW3;
    // how wide is the output of the three-input adders at each r_Pipeline stage?
    // WORST CASE: all input bits are '1'
    localparam PIPELINE_WIDTH = $clog2(VECTOR_WIDTH);

    /////////////////////////////////////////////////////////////////////////////////////
    // PAD INPUT VECTOR
    wire [EXT_VECTOR_WIDTH-1:0] w_ExtendedVector;
    assign w_ExtendedVector = {i_Vector, {(EXT_VECTOR_WIDTH-VECTOR_WIDTH){1'b0}}};


    /////////////////////////////////////////////////////////////////////////////////////
    // PIPELINE 0
    // Create sum of bits in every GRANULE_WIDTH slice of the current input 
    // vector.
    // Assign the result to the corresponding three bits of the 6BitSum
    // register. (3 is the maximum output width at this stage, as it is the
    // proper size for the largest granule that makes sense (6-bits wide).
    wire [$clog2(GRANULE_WIDTH)-1:0] w_GranuleSum[EXT_VECTOR_WIDTH/GRANULE_WIDTH-1:0];

    genvar ii;
    generate
        for(ii = 0; ii < (EXT_VECTOR_WIDTH/GRANULE_WIDTH); ii =ii + 1) begin
            bit_adder
            #(  .VECTOR_WIDTH(GRANULE_WIDTH) )
            first_stage_adder(
                .i_Vector(w_ExtendedVector[ii*GRANULE_WIDTH+:GRANULE_WIDTH]),
                .o_Sum(w_GranuleSum[ii])
            );
        end
    endgenerate

    /////////////////////////////////////////////////////////////////////////////////////
    // PIPELINE STAGE 1-to-N
    // Add three of the results from the previous stage in every stage.
    // The pipeline itself is an array of three input adder output registers
    // of appropriate sizing.
    reg [PIPELINE_WIDTH:0] r_Pipeline [EXT_VECTOR_WIDTH/GW3*(PIPELINE_DEPTH+1):0];

    genvar jj, kk;
    generate
        for(jj = 0; jj < PIPELINE_DEPTH+1; jj = jj + 1) begin
            if(jj == PIPELINE_DEPTH) begin
                for(kk = 0; kk < 3**jj; kk = kk + 1) begin
                    always @ (posedge clk)
                    begin
                        if(rst) begin
                            r_Pipeline[3**jj + kk] <= 0;
                        end else begin
                            r_Pipeline[3**jj + kk] <= w_GranuleSum[3*kk]    +
                                                    w_GranuleSum[3*kk + 1]  +
                                                    w_GranuleSum[3*kk + 2];
                        end
                    end
                end 
            end
            else begin
                for(kk = 0; kk < 3**jj; kk = kk + 1) begin
                    always @ (posedge clk)
                    begin
                        if(rst) begin
                            r_Pipeline[3**jj + kk] <= 0;
                        end else begin
                            r_Pipeline[3**jj + kk] <= r_Pipeline[3**(jj+1) + 3*kk]    +
                                                    r_Pipeline[3**(jj+1) + 3*kk + 1]  +
                                                    r_Pipeline[3**(jj+1) + 3*kk + 2];
                        end
                    end
                end 
            end
        end
    endgenerate

    assign o_Sum = r_Pipeline[1];

endmodule

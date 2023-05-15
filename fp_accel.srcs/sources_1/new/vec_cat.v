`timescale 1ns / 1ps
`default_nettype none

// To the input of the accelerator, vectors will arrive one after another,
// without being separated from each other into different data words. The
// purpose of this module is to do this separation. As the vector width is
// different from the bus width, the last piece of each vector will be padded
// with zeros on the output. (Zeroes don't influence the result of counting
// 1 bits.)
//
// [ASSUMPTION]: The vector width is never more than twice the width of the
// input bus.



module vec_cat
    #(
        BUS_WIDTH = 512,
        VECT_WIDTH = 920,
        CAT_REG_NO = 8          // how many times the bus width is the input shiftreg
    )
    (
        input wire clk,
        input wire rst,
        input wire [BUS_WIDTH-1:0] i_Vector,    // continuous stream of unseparated vectors
        input wire i_Valid,                     // i_Vector is valid
        output wire [BUS_WIDTH-1:0] o_Vector,   // stream of separated vectors, only one vector per output word
        output wire o_Valid                     // o_Vector is valid
    );

    localparam DELTA = BUS_WIDTH - (VECT_WIDTH-BUS_WIDTH);      // step distance in each iterateion
    localparam IDX_PERMUATATIONS = BUS_WIDTH*CAT_REG_NO*2/DELTA;  // total no of possible output lower indexes
    
    localparam [0:0] FULL_V = 1'b0;
    localparam [0:0] PAD_V = 1'b1;

    /////////////////////////////////////////////////////////////////////////////////////
    // VECTOR SHIFT --> store current and previous CAT_REG_NO numver of input vectors
    reg [CAT_REG_NO*BUS_WIDTH-1:0] r_InnerVector;

    genvar ii;
    generate
        for(ii = 1; ii < CAT_REG_NO; ii = ii + 1) begin
            if(ii == 1) begin
                always @ (posedge clk) begin
                    r_InnerVector[BUS_WIDTH-1:0] <= i_Vector;
                end
            end else begin
                always @ (posedge clk) begin
                    r_InnerVector[ii*BUS_WIDTH-1:(ii-1)*BUS_WIDTH] <= r_InnerVector[(ii-1)*BUS_WIDTH-1:(ii-2)*BUS_WIDTH];
                end
            end
        end
    endgenerate


    /////////////////////////////////////////////////////////////////////////////////////
    // STATE MACHINE
    // --> state changes every clk as it is assumed that VECT_WIDTH < 2*BUS_WIDTH
    reg r_State;
    reg [15:0] r_IterationCntr; // counts full vector emissions

    always @ (posedge clk)
    begin
        if(rst) begin
            r_State <= FULL_V;
            r_IterationCntr <= 0;
        end else begin
            r_State <= ~r_State;
            r_IterationCntr <= r_IterationCntr + 1;
        end
    end


    /////////////////////////////////////////////////////////////////////////////////////
    // OUTPUT VECTOR ARRAY
    // --> all possible index variations for the output vector need to be
    // wired into a single multiplexer, then selected between with the r_State
    // signal and the currently calculated indexes.
    reg [2:0] r_ValidShr;        // delayed valid signal
    reg [BUS_WIDTH-1:0] r_OutVectorArray[IDX_PERMUATATIONS-1:0];

    always @ (posedge clk)
    begin
        r_ValidShr[0] <= i_Valid;    
        r_ValidShr[2:1] <= r_ValidShr[1:0];
    end

    genvar jj;  // steps vector index
    generate
        for(jj = 0; jj < CAT_REG_NO*BUS_WIDTH; jj = jj + 1) begin
            always @ (posedge clk)
            begin
                if(r_State == FULL_V) begin
                    r_OutVectorArray[jj] <= r_InnerVector[jj*DELTA+BUS_WIDTH-1:jj*DELTA];
                end else begin
                    r_OutVectorArray[jj] <= {r_InnerVector[jj*DELTA+BUS_WIDTH-1:(jj+1)*DELTA], {DELTA{1'b0}}};
                end
            end
        end
    endgenerate


    /////////////////////////////////////////////////////////////////////////////////////
    // SELECT OUTPUT
    // --> select the correct output from the r_OutVectorArray register array
    assign o_Vector = r_OutVectorArray[r_IterationCntr];
    assign o_Valid = r_ValidShr[2];
    



    
    endmodule

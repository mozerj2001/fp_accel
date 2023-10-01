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
        VECTOR_WIDTH = 920
    )
    (
        input wire clk,
        input wire rst,
        input wire [BUS_WIDTH-1:0] i_Vector,    // continuous stream of unseparated vectors
        input wire i_Valid,                     // external FIFO not empty
        output wire [BUS_WIDTH-1:0] o_Vector,   // stream of separated vectors, only one vector per output word
        output wire o_Valid,                    // o_Vector is valid
	    output wire o_Read			            // signal that no new vector can be processed in the next cycle
    );

    localparam CAT_REG_NO		    = 2;

    localparam DELTA 			    = BUS_WIDTH - (VECTOR_WIDTH-BUS_WIDTH); // step distance in each iterateion
    localparam IDX_PERMUATATIONS 	= BUS_WIDTH*CAT_REG_NO*2/DELTA;  	    // total no of possible output lower indexes
    
    localparam [0:0] FULL_V 		= 1'b0;
    localparam [0:0] PAD_V 		    = 1'b1;

    localparam PAUSE_ITER 		    = BUS_WIDTH/DELTA;			            // no of iterations, after which no sub vector can be read for a clk

    /////////////////////////////////////////////////////////////////////////////////////
    // VECTOR SHIFT --> store current and previous CAT_REG_NO number of input vectors
    reg [CAT_REG_NO*BUS_WIDTH-1:0] r_InnerVector;

    genvar ii;
    generate
        for(ii = 1; ii <= CAT_REG_NO; ii = ii + 1) begin
            if(ii == 1) begin
                always @ (posedge clk) begin
                    if(i_Valid && ~w_PauseIterCntr) begin
                        r_InnerVector[BUS_WIDTH-1:0] <= i_Vector;
                    end
                end
            end else begin
                always @ (posedge clk) begin
                    if(i_Valid && ~w_PauseIterCntr) begin
                        r_InnerVector[ii*BUS_WIDTH-1:(ii-1)*BUS_WIDTH] <= r_InnerVector[(ii-1)*BUS_WIDTH-1:(ii-2)*BUS_WIDTH];
                    end
                end
            end
        end
    endgenerate


    /////////////////////////////////////////////////////////////////////////////////////
    // STATE MACHINE
    // --> state changes every clk as it is assumed that VECTOR_WIDTH < 2*BUS_WIDTH
    reg         r_State;
    reg [15:0]  r_IterationCntr; // counts full vector emissions
    reg         r_RstIterCntr;

    wire w_PauseIterCntr;
    assign w_PauseIterCntr = (r_State == PAD_V) && (r_IterationCntr*DELTA == BUS_WIDTH);

    always @ (posedge clk)
    begin
        if(rst) begin
            r_State <= PAD_V;
        end else if(i_Valid) begin
            r_State <= ~r_State;
        end
    end

    always @ (posedge clk)
    begin
        if(rst) begin
            r_RstIterCntr <= 0;
        end else if(w_PauseIterCntr) begin
            r_RstIterCntr <= 1;
        end else begin
            r_RstIterCntr <= 0;
        end
    end

    always @ (posedge clk)
    begin
        if(rst) begin
            r_IterationCntr <= 0;
        end else if(r_RstIterCntr) begin
            r_IterationCntr <= 1;
	    end else if(w_PauseIterCntr) begin
	        r_IterationCntr <= r_IterationCntr;
        end else if(~(i_Valid)) begin
            r_IterationCntr <= 0;
        end else if(r_State == PAD_V) begin
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
                end else if(r_State == PAD_V) begin
                    r_OutVectorArray[jj] <= {r_InnerVector[jj*DELTA+BUS_WIDTH-1:(jj+1)*DELTA], {DELTA{1'b0}}};
                end
            end
        end
    endgenerate


    /////////////////////////////////////////////////////////////////////////////////////
    // SELECT OUTPUT
    // --> select the correct output from the r_OutVectorArray register array
    assign o_Vector = r_OutVectorArray[r_IterationCntr-1];
    assign o_Valid  = r_ValidShr[1];
    assign o_Read   = i_Valid && ~w_PauseIterCntr;

    
    endmodule

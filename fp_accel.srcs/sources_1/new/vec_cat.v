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
        VECT_WIDTH = 920
    )
    (
        input wire clk,
        input wire rst,
        input wire [BUS_WIDTH-1:0] i_Vector,    // continuous stream of unseparated vectors
        input wire i_Valid,                     // i_Vector is valid
        output wire [BUS_WIDTH-1:0] o_Vector,   // stream of separated vectors, only one vector per output word
        output wire o_Valid                     // o_Vector is valid
    );

    localparam IDX_HIGH_WIDTH = $clog2(BUS_WIDTH) + 1;  // addresses up to the MSB of r_InnerVector
    localparam IDX_LOW_WIDTH = $clog2(BUS_WIDTH);       // never higher than half the r_InnerVector
    localparam BIT_CNTR_WIDTH = $clog2(VECT_WIDTH);
    localparam DELTA = BUS_WIDTH - (VECT_WIDTH-BUS_WIDTH);
    
    localparam [0:0] FULL_V = 1'b0;
    localparam [0:0] PAD_V = 1'b1;

    /////////////////////////////////////////////////////////////////////////////////////
    // VECTOR SHIFT --> store current and previous input vector
    reg [2*BUS_WIDTH-1:0] r_InnerVector;

    always @ (posedge clk)
    begin
        if(i_Valid) begin
            r_InnerVector[BUS_WIDTH-1:0] <= i_Vector;
            r_InnerVector[2*BUS_WIDTH-1:BUS_WIDTH] <= r_InnerVector[BUS_WIDTH-1:0];
        end
    end


    /////////////////////////////////////////////////////////////////////////////////////
    // STATE MACHINE
    // --> state changes every clk as it is assumed that VECT_WIDTH < 2*BUS_WIDTH
    reg r_State;

    always @ (posedge clk)
    begin
        if(rst) begin
            r_State <= FULL_V;
        end else begin
            r_State <= ~r_State;
        end
    end
    

    /////////////////////////////////////////////////////////////////////////////////////
    // INDEX REGISTERS --> select output vector from r_InnerVector
    reg [IDX_HIGH_WIDTH-1:0] r_IdxHigh; // MSB of selected interval
    reg [IDX_LOW_WIDTH-1:0] r_IdxLow;   // LSB of selected interval
    reg [BIT_CNTR_WIDTH-1:0] r_BitCntr; // how many bits have been emitted as part of the current vector?

    wire [IDX_HIGH_WIDTH-1:0] w_IdxHighNext;
    assign w_IdxHighNext = (r_BitCntr == 0) ? (r_IdxHigh) : (w_IdxLowNext + BUS_WIDTH-1);

    reg [IDX_LOW_WIDTH-1:0] w_IdxLowNext;
    always @ (*)
    begin
        case(r_State)
            FULL_V: begin
                if((r_IdxLow + DELTA) <= BUS_WIDTH) begin
                    w_IdxLowNext <= r_IdxLow + DELTA;
                end else begin
                    w_IdxLowNext <= r_IdxLow + DELTA - BUS_WIDTH;
                end
            end
            PAD_V:
                w_IdxLowNext <= r_IdxLow;
            default:
                w_IdxLowNext <= 0;
        endcase
    end

    wire [BIT_CNTR_WIDTH-1:0] w_BitCntrNext;
    assign w_BitCntrNext = r_BitCntr + (r_IdxHigh-r_IdxLow);
    
    wire [BIT_CNTR_WIDTH-1:0] w_BitsRemaining;
    assign w_BitsRemaining = VECT_WIDTH - r_BitCntr;

    always @ (posedge clk)
    begin
        if(rst) begin
            r_IdxHigh = BUS_WIDTH-1;
            r_IdxLow = 0;
            r_BitCntr <= 0;
        end else if(i_Valid) begin
            r_IdxHigh = w_IdxHighNext;
            r_IdxLow = w_IdxLowNext;

            if(w_BitCntrNext == VECT_WIDTH) begin
                r_BitCntr <= 0;
            end else begin
                r_BitCntr <= w_BitCntrNext;
            end
        end
    end
    

    /////////////////////////////////////////////////////////////////////////////////////
    // OUTPUT
    //reg r_Valid;
    //wire [VECT_WIDTH-(BUS_WIDTH-DELTA)-1:0] w_VectorOutMux[BUS_WIDTH-1:0];

    //always @ (posedge clk)
    //begin
    //    r_Valid <= i_Valid;    
    //end

    //genvar ii;
    //generate
    //    for(ii = 0; ii < VECT_WIDTH-(BUS_WIDTH-DELTA); ii = ii + 1) begin
    //        if(r_State == FULL_V) begin
    //            w_VectorOutMux <= r_InnerVector[i+:BUS_WIDTH];
    //        end else begin
    //            w_VectorOutMux <= {r_InnerVector[i+:}
    //        end
    //    end
    //endgenerate


endmodule

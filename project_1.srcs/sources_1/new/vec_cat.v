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
        BUS_WIDTH       = 512,
        VECTOR_WIDTH    = 920,
        VEC_ID_WIDTH    = 8
    )
    (
        input wire                      clk,
        input wire                      rst,
        input wire [BUS_WIDTH-1:0]      i_Vector,       // continuous stream of unseparated vectors
        input wire                      i_Valid,        // external FIFO not empty
        output wire [BUS_WIDTH-1:0]     o_Vector,       // stream of separated vectors, only one vector per output word
        output wire [VEC_ID_WIDTH-1:0]  o_VecID,
        output wire                     o_Valid,        // o_Vector is valid
	    output wire                     o_Read          // signal that no new vector can be processed in the next cycle
    );

    localparam CAT_REG_NO		    = 2                                 ;   // min. 2
    localparam DELTA 			    = 2*BUS_WIDTH - VECTOR_WIDTH        ;   // step distance in each iterateion
    localparam IDX_REG_WIDTH        = $clog2((CAT_REG_NO-1)*BUS_WIDTH)+1;
    localparam FULL                 = 0                                 ;
    localparam PAD                  = 1                                 ;
    

    /////////////////////////////////////////////////////////////////////////////////////
    // VECTOR SHIFT --> store current and previous CAT_REG_NO number of input vectors
    reg [CAT_REG_NO*BUS_WIDTH-1:0] r_InnerVector;

    genvar ii;
    generate
        for(ii = 1; ii <= CAT_REG_NO; ii = ii + 1) begin
            if(ii == 1) begin
                always @ (posedge clk) begin
                    if(i_Valid && ~w_Overflow) begin
                        r_InnerVector[BUS_WIDTH-1:0] <= i_Vector;
                    end
                end
            end else begin
                always @ (posedge clk) begin
                    if(i_Valid && ~w_Overflow) begin
                        r_InnerVector[ii*BUS_WIDTH-1:(ii-1)*BUS_WIDTH] <= r_InnerVector[(ii-1)*BUS_WIDTH-1:(ii-2)*BUS_WIDTH];
                    end
                end
            end
        end
    endgenerate


    /////////////////////////////////////////////////////////////////////////////////////
    // VALID DELAY SHIFT --> delay the i_Valid signal for scheduling and
    // output valid
    reg [2:0] r_ValidShr;

    always @ (posedge clk)
    begin
        if(rst) begin
            r_ValidShr <= 0;
        end else begin
            r_ValidShr[0] <= i_Valid;
            r_ValidShr[1] <= r_ValidShr[0];
            r_ValidShr[2] <= r_ValidShr[1];
        end
    end


    /////////////////////////////////////////////////////////////////////////////////////
    // PERMUTATION ARRAY --> wire array out of which concatenated output
    // vectors will be selected by r_IdxReg
    wire [BUS_WIDTH-1:0] w_PermArray [CAT_REG_NO*BUS_WIDTH-1:0];

    genvar jj;
    generate
        for(jj = 0; jj <= (CAT_REG_NO-1)*BUS_WIDTH; jj = jj + 1) begin
            assign w_PermArray[jj] = r_InnerVector[jj+BUS_WIDTH-1 -: BUS_WIDTH];
        end
    endgenerate


    /////////////////////////////////////////////////////////////////////////////////////
    // CREATE OUTPUT
    reg [IDX_REG_WIDTH-1:0] r_IdxReg;
    reg                     r_State;
    wire                    w_Overflow;
    assign w_Overflow = ((r_IdxReg + DELTA) > (CAT_REG_NO-1)*BUS_WIDTH) && (r_State == PAD);    // 1, when information from the next vector would be shifted out

    always @ (posedge clk)
    begin
        if(rst) begin
            r_State <= PAD;
        end else if(i_Valid) begin
            r_State <= ~r_State;
        end
    end

    always @ (posedge clk)
    begin
        if(rst) begin
            r_IdxReg = 0;
        end else if(r_State == PAD && ~w_Overflow && r_ValidShr[1]) begin
            r_IdxReg = r_IdxReg + DELTA;
        end else if(w_Overflow) begin
            r_IdxReg = r_IdxReg - (BUS_WIDTH-DELTA);                            // no shift due to information loss --> step back
        end
    end


    /////////////////////////////////////////////////////////////////////////////////////
    // CREATE VECTOR ID
    reg [VEC_ID_WIDTH-1:0] r_IDCntr;

    always @ (posedge clk)
    begin
        if(rst) begin
            r_IDCntr <= {VEC_ID_WIDTH{1'b1}};
        end else if(i_Valid && (r_State == PAD)) begin
            r_IDCntr <= r_IDCntr + 1;
        end
    end


    /////////////////////////////////////////////////////////////////////////////////////
    // SELECT OUTPUT
    // --> select the correct output from the r_OutVectorArray register array
    assign o_Vector = (r_State == FULL) ? w_PermArray[r_IdxReg] : {w_PermArray[r_IdxReg][BUS_WIDTH-1:DELTA], {DELTA{1'b0}}};
    assign o_VecID  = r_IDCntr;
    assign o_Valid  = r_ValidShr[0];
    assign o_Read   = i_Valid && ~w_Overflow;

    
    endmodule

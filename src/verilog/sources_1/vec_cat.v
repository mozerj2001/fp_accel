`ifndef VEC_CAT
`define VEC_CAT

`timescale 1ns / 1ps
`default_nettype none


/* 
 * MODULE: VEC_CAT
 * To the input of the accelerator, vectors will arrive one after another,
 * without being separated from each other into different data words. The
 * purpose of this module is to do this separation. As the vector width is
 * different from the bus width, the last piece of each vector will be padded
 * with zeros on the output. (Zeroes don't influence the result of counting
 * 1 bits.)
 */

module vec_cat
    #(
        BUS_WIDTH       = 128,
        VECTOR_WIDTH    = 920,
        VEC_ID_WIDTH    = 8,
        //
        SUB_VEC_NO      = $rtoi($ceil($itor(VECTOR_WIDTH)/$itor(BUS_WIDTH)))
    )
    (
        input wire                      clk,
        input wire                      rstn,

        // input vector stream interface
        input wire [BUS_WIDTH-1:0]      up_Vector,       // continuous stream of unseparated vectors
        input wire                      up_Valid,        // external FIFO not empty
        input wire                      up_Last,         // last sub-vector to arrive
	    output wire                     up_Ready,         // signal that no new vector can be processed in the next cycle

        // output concatenated vector interface
        output wire [BUS_WIDTH-1:0]     dn_Vector,       // stream of separated vectors, only one vector per output word
        output wire [VEC_ID_WIDTH-1:0]  dn_VecID,
        output wire                     dn_Valid,        // dn_Vector is valid
        output wire                     dn_Last,         // last subvector un current compare batch
        input wire                      dn_Ready         // read next sub-vector

    );

    localparam CAT_REG_NO		    = 2                                  ;  // min. 2
    localparam DELTA 			    = SUB_VEC_NO*BUS_WIDTH - VECTOR_WIDTH;  // step distance in each iterateion
    localparam IDX_REG_WIDTH        = $clog2((CAT_REG_NO-1)*BUS_WIDTH)+1 ;
    localparam FULL                 = 0                                  ;
    localparam PAD                  = 1                                  ;
    
    // internal valid signal
    wire w_DoShift;
    assign w_DoShift = up_Valid && dn_Ready;


    /////////////////////////////////////////////////////////////////////////////////////
    // STATE
    reg r_State;
    wire w_PadNext;
    wire w_FullNext;

    assign w_PadNext = (r_State == FULL) && (r_SubVecCntr == SUB_VEC_NO-2) && w_ValidOut && dn_Ready; // current emitted subvec is next-to-last
    assign w_FullNext = (r_State == PAD) && w_ValidOut && dn_Ready;              // current emitted subvec is padded

    always @ (posedge clk)
    begin
        if(!rstn) begin
            r_State <= FULL;
        end else if(w_PadNext) begin
            r_State <= PAD;
        end else if(w_FullNext) begin
            r_State <= FULL;
        end
    end


    /////////////////////////////////////////////////////////////////////////////////////
    // REVERSED VECTOR
    // - reverse input vector endianness
    // - needed because SW writes bytes from least significant to most significant, but
    // the hardware treats it the other way
    reg [BUS_WIDTH-1:0]             r_ReversedVector;

    always @ (*) begin
        for(integer ii = 0; ii < BUS_WIDTH; ii = ii + 1) begin
            r_ReversedVector[ii] <= up_Vector[BUS_WIDTH-ii-1];
        end
    end

    /////////////////////////////////////////////////////////////////////////////////////
    // VECTOR SHIFT --> store current and previous CAT_REG_NO number of input vectors
    reg [CAT_REG_NO*BUS_WIDTH-1:0]  r_InnerVector;
    wire                            w_Overflow;
    reg                             r_OverflowDel;

    genvar ii;
    generate
        for(ii = 1; ii <= CAT_REG_NO; ii = ii + 1) begin
            if(ii == 1) begin
                always @ (posedge clk) begin
                    if(w_DoShift && ~w_Overflow) begin
                        r_InnerVector[BUS_WIDTH-1:0] <= r_ReversedVector;
                    end
                end
            end else begin
                always @ (posedge clk) begin
                    if(w_DoShift && ~w_Overflow) begin
                        r_InnerVector[ii*BUS_WIDTH-1:(ii-1)*BUS_WIDTH] <= r_InnerVector[(ii-1)*BUS_WIDTH-1:(ii-2)*BUS_WIDTH];
                    end
                end
            end
        end
    endgenerate

    always @ (posedge clk)
    begin
        if(!rstn) begin
            r_OverflowDel <= 1'b0;
        end else begin
            r_OverflowDel <= w_Overflow;
        end
    end


    /////////////////////////////////////////////////////////////////////////////////////
    // VALID DELAY SHIFT --> delay the up_Valid signal for scheduling and
    // output valid, also delay TLAST
    reg [2:0] r_ValidShr;
    reg [2:0] r_LastShr;

    always @ (posedge clk)
    begin
        if(!rstn) begin
            r_ValidShr <= 0;
            r_LastShr <= 0;
        end else if(dn_Ready) begin
            r_ValidShr[0] <= up_Valid;
            r_ValidShr[1] <= r_ValidShr[0];
            r_ValidShr[2] <= r_ValidShr[1];

            r_LastShr[0] <= up_Last;
            r_LastShr[1] <= r_LastShr[0];
            r_LastShr[2] <= r_LastShr[1];
        end
    end


    /////////////////////////////////////////////////////////////////////////////////////
    // PERMUTATION ARRAY --> wire array out of which concatenated output
    // vectors will be selected by r_IdxReg
    wire [BUS_WIDTH-1:0] w_PermArray [CAT_REG_NO*BUS_WIDTH-1:0];

    genvar jj;
    generate
        for(jj = 0; jj <= CAT_REG_NO*BUS_WIDTH; jj = jj + 1) begin
            assign w_PermArray[jj] = (jj <= (CAT_REG_NO-1)*BUS_WIDTH) ? r_InnerVector[jj+BUS_WIDTH-1 -: BUS_WIDTH] : 0;
        end
    endgenerate


    /////////////////////////////////////////////////////////////////////////////////////
    // CREATE OUTPUT
    reg [IDX_REG_WIDTH-1:0]         r_IdxReg;
    reg [$clog2(SUB_VEC_NO)-1:0]    r_SubVecCntr;
    wire                            w_ValidOut;
    
    // 1 when unemitted parts of the next word would be shifted out of the input shift-register
    assign w_Overflow = ((r_IdxReg + DELTA) > (CAT_REG_NO-1)*BUS_WIDTH) && w_FullNext;

    assign w_ValidOut = r_ValidShr[0] || r_OverflowDel;

    always @ (posedge clk)
    begin
        if(!rstn) begin
            r_SubVecCntr <= 0;
        end else if(w_ValidOut && dn_Ready && (r_State == PAD)) begin
            r_SubVecCntr <= 0;
        end else if(w_ValidOut && dn_Ready) begin
            r_SubVecCntr <= r_SubVecCntr + 1;
        end
    end

    wire                            w_StepIdxUp;
    wire                            w_StepIdxDown;

    assign w_StepIdxUp      = w_FullNext && ~w_Overflow;    // increment when state goes PAD --> FULL
    assign w_StepIdxDown    = w_Overflow && dn_Ready;

    always @ (posedge clk)
    begin
        if(!rstn) begin
            r_IdxReg = 0;
        end else if(w_StepIdxUp) begin
            r_IdxReg = r_IdxReg + DELTA;
        end else if(w_StepIdxDown) begin
            r_IdxReg = r_IdxReg - (BUS_WIDTH-DELTA);                            // no shift due to information loss --> step back
        end
    end


    /////////////////////////////////////////////////////////////////////////////////////
    // CREATE VECTOR ID
    // ID 0 is reserved
    reg [VEC_ID_WIDTH-1:0] r_IDCntr;

    always @ (posedge clk)
    begin
        if(!rstn) begin
            r_IDCntr <= 1;
        end else if(w_FullNext) begin
            r_IDCntr <= r_IDCntr + 1;
        end
    end


    /////////////////////////////////////////////////////////////////////////////////////
    // SELECT OUTPUT
    // --> select the correct output from the r_OutVectorArray register array

    assign dn_Vector = (r_State == FULL) ? w_PermArray[r_IdxReg] : {w_PermArray[r_IdxReg][BUS_WIDTH-1:DELTA], {DELTA{1'b0}}};
    assign dn_VecID  = r_IDCntr;
    assign dn_Valid  = w_ValidOut;
    assign up_Ready  = w_DoShift && ~w_Overflow;
    assign dn_Last   = r_LastShr[0] && w_ValidOut;

    
    endmodule

`endif

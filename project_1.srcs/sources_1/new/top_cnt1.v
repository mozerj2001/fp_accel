`timescale 1ns / 1ps
`default_nettype none

// VECTOR WEIGHT CALCULATOR TOP MODULE

module top_cnt1
    #(
        BUS_WIDTH           = 512,    // system bus data width
        VECTOR_WIDTH        = 920,
        SUB_VECTOR_NO       = 2,    // how many sub-vectors are in a full vector
        GRANULE_WIDTH       = 6,    // width of the first CNT1 tree stage, 6 on Xilinx FPGA
        SHR_DEPTH           = 4,    // how many vectors this module is able to store
        //
        CNT_WIDTH           = $clog2(VECTOR_WIDTH)
    )(
        input wire                  clk,
        input wire                  rst,
        input wire [BUS_WIDTH-1:0]  i_Vector,
        input wire                  i_Valid,
        input wire                  i_LoadNewRefVectors,    // 0: shift A, 1: shift B
        //
        output wire [CNT_WIDTH-1:0] o_CntA,
        output wire [CNT_WIDTH-1:0] o_CntB,
        output wire [CNT_WIDTH-1:0] o_Cnt_AnB,
        output wire                 o_Valid,
        output wire                 o_Read
    );

    localparam SUB_VEC_CNTR_WIDTH = $clog2(SUB_VECTOR_NO*SHR_DEPTH);

    localparam LOAD_REF = 1'b0;
    localparam COMPARE  = 1'b1;

    // SUB VECTOR COUNTER
    // Counts sub-vectors incoming from the input pre_stage_unit.
    reg [SUB_VEC_CNTR_WIDTH-1:0] r_SubVecCntr;

    always @ (posedge clk)
    begin
        if(rst) begin
            r_SubVecCntr <= 0;
        end else if(i_LoadNewRefVectors) begin
            r_SubVecCntr <= 0;
        end else if(w_Cnt_SubVector_Valid) begin
            r_SubVecCntr <= r_SubVecCntr + 1;
        end
    end


    // STATE MACHINE
    reg r_State;

    always @ (posedge clk)
    begin
        if(rst) begin
            r_State <= LOAD_REF;
        end else if(i_LoadNewRefVectors) begin
            r_State <= LOAD_REF;
        end else if(r_SubVecCntr == (SHR_DEPTH*SUB_VECTOR_NO-1)) begin
            r_State <= COMPARE;
        end
    end



    // VECTOR CONCATENATOR UNIT
    // If the total vector width is not divisable by BUS_WIDTH, the vec_cat
    // module ensures that vectors aren't mixed up, thus will receive correct
    // CNT1 values.
    wire [BUS_WIDTH-1:0]    w_Catted_Vector;
    wire                    w_Catted_Valid;
    vec_cat #(
        .BUS_WIDTH(BUS_WIDTH),
        .VECTOR_WIDTH(VECTOR_WIDTH)
    ) u_vec_cat_0 (
        .clk        (clk),
        .rst        (rst),
        .i_Vector   (i_Vector),
        .i_Valid    (i_Valid),
        .o_Vector   (w_Catted_Vector),
        .o_Valid    (w_Catted_Valid),
        .o_Read     (o_Read)
    );


    // INPUT CNT1 UNIT
    // Calculates input vector weight.
    wire [BUS_WIDTH-1:0]    w_Cnted_Vector;
    wire [CNT_WIDTH-1:0]    w_Cnt;
    wire                    w_Cnt_SubVector_Valid;
    wire                    w_Cnt_New;
    pre_stage_unit #(
        .BUS_WIDTH(BUS_WIDTH),
        .SUB_VECTOR_NO(SUB_VECTOR_NO),
        .GRANULE_WIDTH(GRANULE_WIDTH)
    ) u_cnt1_in (
        .clk            (clk),
        .rst            (rst),
        .i_Vector       (w_Catted_Vector),
        .i_Valid        (w_Catted_Valid),
        .o_SubVector    (w_Cnted_Vector),
        .o_Valid        (w_Cnt_SubVector_Valid),
        .o_Cnt          (w_Cnt),
        .o_CntNew       (w_Cnt_New)
    );


    // VECTOR SHIFTREGISTERS
    // Store sub_vectors in arrival order. r_State selects whether an
    // A vector or a B vector is being written.
    wire w_Shift_A;
    assign w_Shift_A = w_Cnt_SubVector_Valid && (r_State == LOAD_REF);

    wire w_Shift_B;
    assign w_Shift_B = w_Cnt_SubVector_Valid && (r_State == COMPARE);

    reg [BUS_WIDTH-1:0]         r_Vector_Array_A[SHR_DEPTH-1:0];
    reg [BUS_WIDTH-1:0]         r_Vector_Array_B[SHR_DEPTH-1:0];

    integer ii;
    always @ (posedge clk)
    begin
    if(w_Shift_A) begin
        r_Vector_Array_A[0] <= w_Cnted_Vector;
        for(ii = 1; ii < SHR_DEPTH; ii = ii + 1) begin
            r_Vector_Array_A[ii] <= r_Vector_Array_A[ii-1];
        end
    end else if(w_Shift_B) begin
        r_Vector_Array_B[0] <= w_Cnted_Vector;
        for(ii = 1; ii < SHR_DEPTH; ii = ii + 1) begin
            r_Vector_Array_B[ii] <= r_Vector_Array_B[ii-1];
        end
    end
    end


    // CNT SHIFTREGISTERS
    // Store CNT1 reslults from the pre-stage unit in a LUT shiftregister.
    // r_State selects whether the results are from A or B vectors, similarly
    // to the VECTOR SHIFTREGISTERS.
    wire w_Shift_CntA;
    wire [BUS_WIDTH-1:0] w_Shr_A_Cnt_Out;
    assign w_Shift_CntA = w_Cnt_New && (r_State == LOAD_REF);

    wire w_Shift_CntB;
    wire [BUS_WIDTH-1:0] w_Shr_B_Vec_Out;
    assign w_Shift_CntB = w_Cnt_New && (r_State == COMPARE);

    reg [CNT_WIDTH-1:0] r_Cnt_Array_A[SHR_DEPTH-1:0];
    reg [CNT_WIDTH-1:0] r_Cnt_Array_B[SHR_DEPTH-1:0];

    integer jj;
    always @ (posedge clk)
    begin
    if(w_Shift_CntA) begin
        r_Cnt_Array_A[0] <= w_Cnt;
        for(jj = 1; jj < SHR_DEPTH; jj = jj + 1) begin
            r_Cnt_Array_A[jj] <= r_Cnt_Array_A[jj-1];
        end
    end else if(w_Shift_CntB) begin
        r_Cnt_Array_B[0] <= w_Cnt;
        for(jj = 1; jj < SHR_DEPTH; jj = jj + 1) begin
            r_Cnt_Array_B[jj] <= r_Cnt_Array_B[jj-1];
        end
    end
    end


    // CNT1 A&B
    // Calculates the weight of A&B vectors.
    genvar kk;
    generate
    for(kk = 0; kk < SHR_DEPTH; kk = kk + 1) begin
            pre_stage_unit #(
                .BUS_WIDTH(BUS_WIDTH),
                .SUB_VECTOR_NO(SUB_VECTOR_NO),
                .GRANULE_WIDTH(GRANULE_WIDTH)
            ) u_cnt1_out (
                .clk            (clk),
                .rst            (rst),
                .i_Vector       (r_Vector_Array_A[kk] && r_Vector_Array_B[kk]),
                .i_Valid        (),
                .o_SubVector    (),
                .o_Valid        (),
                .o_Cnt          (o_Cnt_AnB),
                .o_CntNew       (o_Valid)
            );
    end
    endgenerate


    // CNT OUT DELAY SHIFTREGISTER
    // CNT values read from the shiftregisters need to be delayed until the
    // corresponding CNT(A&B) is calculated, then emitted.


endmodule

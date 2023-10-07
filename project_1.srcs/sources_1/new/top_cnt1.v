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
        output wire                 o_Read
    );

    localparam SUB_VEC_CNTR_WIDTH = 16; //$clog2(SUB_VECTOR_NO*SHR_DEPTH);

    localparam LOAD_REF = 1'b0;
    localparam COMPARE  = 1'b1;

    localparam DELAY = $rtoi($ceil($log10($itor(BUS_WIDTH)/($itor(GRANULE_WIDTH)*3.0))/$log10(3.0)));

    // SUB VECTOR COUNTER
    // Counts sub-vectors incoming from the input pre_stage_unit.
    // Assuming there are two sub-vectors per vector, its LSB
    // is the select signal for the output multiplexers.
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


    // VALID SHIFTREGISTER AND STATE SHIFTREGISTER
    // Propagate state and valid gradually along the shiftregisters, so
    // the out pre_stage_units start counting at the appropriate time.
    // SUB_VEC_NO = 2 is assumed.
    reg [SHR_DEPTH-1:0] r_Valid_Shr;
    reg [SHR_DEPTH-1:0] r_State_Shr;

    genvar vv;
    generate
        for(vv = 0; vv < SHR_DEPTH; vv = vv + 1) begin
            if(vv == 0) begin
                always @ (posedge clk)
                begin
                    if(rst) begin
                        r_Valid_Shr[vv] <= 1'b0;
                        r_State_Shr[vv] <= 1'b0;
                    end else if(r_SubVecCntr[0]) begin
                        r_Valid_Shr[vv] <= w_Cnt_SubVector_Valid;
                        r_State_Shr[vv] <= r_State;
                    end
                end
            end else begin
                always @ (posedge clk)
                begin
                    if(rst) begin
                        r_Valid_Shr[vv] <= 1'b0;
                        r_State_Shr[vv] <= 1'b0;
                    end else if(r_SubVecCntr[0]) begin
                        r_Valid_Shr[vv] <= r_Valid_Shr[vv-1];
                        r_State_Shr[vv] <= r_State_Shr[vv-1];
                    end
                end
            end
        end
    endgenerate


    // VECTOR SHIFTREGISTERS
    // Store sub_vectors in arrival order. r_State selects whether an
    // A vector or a B vector is being written.
    // Sub_vectors are aligned on every second clk, therefore one of
    // the sub_vectors needs to be delayed by one clk before being
    // fed to the output CNT1 module.
    wire w_Shift_A;
    assign w_Shift_A = w_Cnt_SubVector_Valid && (r_State == LOAD_REF);

    wire w_Shift_B;
    assign w_Shift_B = w_Cnt_SubVector_Valid && (r_State == COMPARE);

    reg [BUS_WIDTH-1:0]         r_Vector_Array_A[SHR_DEPTH*SUB_VECTOR_NO-1:0];
    reg [BUS_WIDTH-1:0]         r_Vector_Array_B[SHR_DEPTH*SUB_VECTOR_NO-1:0];
    reg [BUS_WIDTH-1:0]         r_Vector_Array_B_Del[SHR_DEPTH-1:0];

    integer ii;
    always @ (posedge clk)
    begin
    if(w_Shift_A) begin
        r_Vector_Array_A[0] <= w_Cnted_Vector;
        for(ii = 1; ii < SHR_DEPTH*SUB_VECTOR_NO; ii = ii + 1) begin
            r_Vector_Array_A[ii] <= r_Vector_Array_A[ii-1];
        end
    end else if(w_Shift_B) begin
        r_Vector_Array_B[0] <= w_Cnted_Vector;
        for(ii = 1; ii < SHR_DEPTH*SUB_VECTOR_NO; ii = ii + 1) begin
            r_Vector_Array_B[ii] <= r_Vector_Array_B[ii-1];
        end
    end
    end

    // Delay one of the sub-vectors for the clk, in which sub-vectors
    // are not aligned in the shr.
    always @ (posedge clk)
    begin
        if(w_Shift_B) begin
            for(ii = 0; ii < SHR_DEPTH; ii = ii+1) begin
                r_Vector_Array_B_Del[ii] <= r_Vector_Array_B[2*ii];
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


    // STAGE OUT MUX
    // Selects which sub_vector is on the input of the output pre_stage_unit
    // for each level of shiftregister blocks.
    // Assuming there are two sub-vectors, the select signal is the
    // LSB of the SubVecCntr.
    // Vectors are perfectly aligned in the shiftregisters every second clk
    // (when r_SubVecCntr == 1),
    // what needs to be multiplexed between is the higher-index
    // sub_vector and the delayed lower index sub_vector.
    wire [BUS_WIDTH-1:0] w_Out_A            [SHR_DEPTH-1:0];
    wire [BUS_WIDTH-1:0] w_Out_B            [SHR_DEPTH-1:0];
    wire [BUS_WIDTH-1:0] w_OutPreStageIn_AnB[SHR_DEPTH-1:0];

    genvar mm;
    generate
        for(mm = 0; mm < SHR_DEPTH; mm = mm + 1) begin
            assign w_OutPreStageIn_AnB[mm] = (~r_SubVecCntr[0]) ?  (r_Vector_Array_A[2*mm+1] & r_Vector_Array_B[2*mm+1]) : 
                                                                (r_Vector_Array_A[2*mm] & r_Vector_Array_B_Del[mm]);
        end
    endgenerate


    // CNT1 A&B
    // Calculates the weight of A&B vectors.
    wire [CNT_WIDTH-1:0] w_Cnt_AnB[SHR_DEPTH-1:0];
    wire [SHR_DEPTH-1:0] w_PreStageOut_Valid;
    wire [SHR_DEPTH-1:0] w_CntOutNew_AnB;
    wire [SHR_DEPTH-1:0] w_PreStageOut_ValidIn;

    assign w_PreStageOut_ValidIn = r_Valid_Shr & r_State_Shr;

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
            .i_Vector       (w_OutPreStageIn_AnB[kk]),
            .i_Valid        (w_PreStageOut_ValidIn[kk]),
            .o_SubVector    (),
            .o_Valid        (w_PreStageOut_Valid[kk]),
            .o_Cnt          (w_Cnt_AnB[kk]),
            .o_CntNew       (w_CntOutNew_AnB[kk])
        );
    end
    endgenerate


    // CNT OUT DELAY SHIFTREGISTER
    // CNT values read from the shiftregisters need to be delayed until the
    // corresponding CNT(A&B) is calculated, then emitted.
    // Using LUT SHR module instead of manually writing 3D reg array...
    reg [CNT_WIDTH-1:0] r_CntDelayedOut_A [SHR_DEPTH-1:0][DELAY:0];
    reg [CNT_WIDTH-1:0] r_CntDelayedOut_B [SHR_DEPTH-1:0][DELAY:0];

    genvar nn;
    genvar oo;
    generate
        for(nn = 0; nn < SHR_DEPTH; nn = nn + 1) begin
            for(oo = 0; oo <= DELAY; oo = oo + 1) begin
                if(oo == 0) begin
                    always @ (posedge clk)
                    begin
                        if(w_PreStageOut_ValidIn[nn]) begin
                            r_CntDelayedOut_A[nn][oo] <= r_Cnt_Array_A[nn];
                            r_CntDelayedOut_B[nn][oo] <= r_Cnt_Array_B[nn];
                        end
                    end
                end else begin
                    always @ (posedge clk)
                    begin
                        if(w_PreStageOut_ValidIn[nn]) begin
                            r_CntDelayedOut_A[nn][oo] <= r_CntDelayedOut_A[nn][oo-1];
                            r_CntDelayedOut_B[nn][oo] <= r_CntDelayedOut_B[nn][oo-1];
                        end
                    end
                end
            end
        end
    endgenerate


endmodule

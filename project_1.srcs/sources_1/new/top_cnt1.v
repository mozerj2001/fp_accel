`timescale 1ns / 1ps
`default_nettype none

// VECTOR WEIGHT CALCULATOR TOP MODULE
// Reads SubVectors from a FIFO, stores ref vectors and their calculated
// weight in an array of shiftregisters. Shifts other incoming vectors
// beside the ref vectors, calculates the weight of every ref_vector
// & compared_vector vector, then calculates CNT(ref)+CNT(comp)-CNT(ref&comp)
// and compares it agains a threshold. Vector IDs under a threshold are
// similar enough, so their ID is propagated through a FIFO-tree.
// (ID is the position in the database, so vec_cat counts input vectors.)

module top_cnt1
    #(
        BUS_WIDTH           = 512,      // system bus data width
        VECTOR_WIDTH        = 920,
        SUB_VECTOR_NO       = 2,        // how many sub-vectors are in a full vector
        GRANULE_WIDTH       = 6,        // width of the first CNT1 tree stage, 6 on Xilinx FPGA
        SHR_DEPTH           = 4,        // how many vectors this module is able to store
        VEC_ID_WIDTH        = 8,
        //
        CNT_WIDTH           = $clog2(VECTOR_WIDTH)
    )(
        input wire                          clk,
        input wire                          rst,
        input wire [BUS_WIDTH-1:0]          i_Vector,
        input wire                          i_Valid,
        input wire                          i_LoadNewRefVectors,    // 0: shift A, 1: shift B
        //
        input wire                          i_WrThreshold,
        input wire [CNT_WIDTH-1:0]          i_Threshold,
        //
        input wire                          i_IDPair_Read,
        //
        output wire                         o_Read,
        output wire                         o_ReadThreshold,
        output wire                         o_ComparatorReady,      // comparator not setting up new threshold
        output wire                         o_IDPair_Ready,
        output wire [2*VEC_ID_WIDTH-1:0]    o_IDPair_Out
    );

    localparam SUB_VEC_CNTR_WIDTH   = 16;   //$clog2(SUB_VECTOR_NO*SHR_DEPTH);
    localparam LOAD_REF             = 1'b0;
    localparam COMPARE              = 1'b1;
    localparam DELAY                = $rtoi($ceil($log10($itor(BUS_WIDTH)/($itor(GRANULE_WIDTH)*3.0))/$log10(3.0))) + 2;

    // SUB VECTOR COUNTER
    // Counts sub-vectors incoming from the input pre_stage_unit.
    // Assuming there are two sub-vectors per vector, its LSB
    // is the select signal for the output multiplexers.
    reg [SUB_VEC_CNTR_WIDTH-1:0] r_SubVecCntr;
    wire w_Cnt_SubVector_Valid;

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
    wire [VEC_ID_WIDTH-1:0] w_CatOut_VecID;

    vec_cat #(
        .BUS_WIDTH      (BUS_WIDTH      ),
        .VECTOR_WIDTH   (VECTOR_WIDTH   ),
        .VEC_ID_WIDTH   (VEC_ID_WIDTH   )
    ) u_vec_cat_0 (
        .clk            (clk            ),
        .rst            (rst            ),
        .i_Vector       (i_Vector       ),
        .i_Valid        (i_Valid        ),
        .o_Vector       (w_Catted_Vector),
        .o_VecID        (w_CatOut_VecID ),
        .o_Valid        (w_Catted_Valid ),
        .o_Read         (o_Read         )
    );


    // INPUT CNT1 UNIT
    // Calculates input vector weight.
    wire [BUS_WIDTH-1:0]    w_Cnted_Vector;
    wire [CNT_WIDTH-1:0]    w_Cnt;
    wire                    w_Cnt_New;
    pre_stage_unit #(
        .BUS_WIDTH      (BUS_WIDTH              ),
        .SUB_VECTOR_NO  (SUB_VECTOR_NO          ),
        .GRANULE_WIDTH  (GRANULE_WIDTH          )
    ) u_cnt1_in (
        .clk            (clk                    ),
        .rst            (rst                    ),
        .i_Vector       (w_Catted_Vector        ),
        .i_Valid        (w_Catted_Valid         ),
        .o_SubVector    (w_Cnted_Vector         ),
        .o_Valid        (w_Cnt_SubVector_Valid  ),
        .o_Cnt          (w_Cnt                  ),
        .o_CntNew       (w_Cnt_New              )
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

    reg [BUS_WIDTH-1:0] r_Vector_Array_A    [SHR_DEPTH*SUB_VECTOR_NO-1:0];
    reg [BUS_WIDTH-1:0] r_Vector_Array_B    [SHR_DEPTH*SUB_VECTOR_NO-1:0];
    reg [BUS_WIDTH-1:0] r_Vector_Array_B_Del[SHR_DEPTH-1:0];

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

    // ID SHIFTREGISTERS
    // Identical to CNT shiftregisters, they store the ID of each vector.
    // SHR0: Compensate the delay of the input pre_stage_unit.  [DELAY]
    // SHR1: Store alongside the CNT value and sub_vectors.     [SHR_DEPTH]
    // SHR2: Compensate output pre_stage_unit and comparison.   [DELAY+2]
    reg [VEC_ID_WIDTH-1:0]  r_ShrID_0   [DELAY-1:0];
    reg [VEC_ID_WIDTH-1:0]  r_ShrID_1_A [SHR_DEPTH-1:0];
    reg [VEC_ID_WIDTH-1:0]  r_ShrID_1_B [SHR_DEPTH-1:0];
    reg [VEC_ID_WIDTH-1:0]  r_ShrID_2_A [SHR_DEPTH-1:0][DELAY+2:0];
    reg [VEC_ID_WIDTH-1:0]  r_ShrID_2_B [SHR_DEPTH-1:0][DELAY+2:0];

    genvar dd;
    generate
        for(dd = 0; dd < DELAY; dd = dd + 1) begin
            always @ (posedge clk)
            begin
                if(dd == 0) begin
                    r_ShrID_0[dd] <= w_CatOut_VecID;
                end else begin
                    r_ShrID_0[dd] <= r_ShrID_0[dd-1];
                end
            end
        end
    endgenerate

    genvar ee;
    generate
        for(ee = 0; ee < SHR_DEPTH; ee = ee + 1) begin
            always @ (posedge clk)
            begin
                if(ee == 0) begin
                    if(w_Cnt_New) begin
                        if(r_State == LOAD_REF) begin
                            r_ShrID_1_A[ee] <= r_ShrID_0[DELAY-1];
                        end else begin
                            r_ShrID_1_B[ee] <= r_ShrID_0[DELAY-1];
                        end
                    end
                end else begin
                    if(w_Cnt_New) begin
                        if(r_State == LOAD_REF) begin
                            r_ShrID_1_A[ee] <= r_ShrID_1_A[ee-1];
                        end else begin
                            r_ShrID_1_B[ee] <= r_ShrID_1_B[ee-1];
                        end
                    end
                end
            end
        end
    endgenerate

    genvar ff;
    genvar gg;
    generate
        for(ff = 0; ff < SHR_DEPTH; ff = ff + 1) begin
            for(gg = 0; gg <= DELAY+2; gg = gg + 1) begin
                if(gg == 0) begin
                    always @ (posedge clk)
                    begin
                        if(w_PreStageOut_ValidIn[ff]) begin
                            r_ShrID_2_A[ff][gg] <= r_ShrID_1_A[ff];
                            r_ShrID_2_B[ff][gg] <= r_ShrID_1_B[ff];
                        end
                    end
                end else begin
                    always @ (posedge clk)
                    begin
                        if(w_PreStageOut_ValidIn[ff]) begin
                            r_ShrID_2_A[ff][gg] <= r_ShrID_2_A[ff][gg-1];
                            r_ShrID_2_B[ff][gg] <= r_ShrID_2_B[ff][gg-1];
                        end
                    end
                end
            end
        end
    endgenerate



    // STAGE OUT MUX
    // Selects which sub_vector is on the input of the output pre_stage_unit
    // for each level of shiftregister blocks.
    // Assuming there are two sub-vectors, the select signal is the
    // LSB of the SubVecCntr.
    // Vectors are perfectly aligned in the shiftregisters every second clk
    // (when r_SubVecCntr == 1),
    // what needs to be multiplexed between is the higher-index
    // sub_vector and the delayed lower index sub_vector.
    wire [BUS_WIDTH-1:0] w_OutPreStageIn_AnB[SHR_DEPTH-1:0];

    genvar mm;
    generate
        for(mm = 0; mm < SHR_DEPTH; mm = mm + 1) begin
            assign w_OutPreStageIn_AnB[mm] = (~r_SubVecCntr[0]) ?   (r_Vector_Array_A[2*mm+1] & r_Vector_Array_B[2*mm+1]) : 
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
            .BUS_WIDTH      (BUS_WIDTH                  ),
            .SUB_VECTOR_NO  (SUB_VECTOR_NO              ),
            .GRANULE_WIDTH  (GRANULE_WIDTH              )
        ) u_cnt1_out (
            .clk            (clk                        ),
            .rst            (rst                        ),
            .i_Vector       (w_OutPreStageIn_AnB[kk]    ),
            .i_Valid        (w_PreStageOut_ValidIn[kk]  ),
            .o_SubVector    (                           ),
            .o_Valid        (w_PreStageOut_Valid[kk]    ),
            .o_Cnt          (w_Cnt_AnB[kk]              ),
            .o_CntNew       (w_CntOutNew_AnB[kk]        )
        );
    end
    endgenerate


    // CNT OUT DELAY SHIFTREGISTER
    // CNT values read from the shiftregisters need to be delayed until the
    // corresponding CNT(A&B) is calculated, then emitted.
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
                            r_CntDelayedOut_A[nn][oo] <= r_Cnt_Array_A[nn];     // required in case new ref vectors are loaded on the fly
                            r_CntDelayedOut_B[nn][oo] <= r_Cnt_Array_B[nn];
                        end
                    end
                end else begin
                    always @ (posedge clk)
                    begin
                        if(w_PreStageOut_ValidIn[nn]) begin
                            r_CntDelayedOut_A[nn][oo] <= r_CntDelayedOut_A[nn][oo-1];     // required in case new ref vectors are loaded on the fly
                            r_CntDelayedOut_B[nn][oo] <= r_CntDelayedOut_B[nn][oo-1];
                        end
                    end
                end
            end
        end
    endgenerate


    // COMPARE MODULES
    // CNT(A)+CNT(B)-CNT(A&B) is the calculated dissimilarity
    // metric. It is compared against a threshold to decide if two
    // fingerprints are similar enough. Output will be collected with
    // a FIFO-tree.
    wire [SHR_DEPTH-1:0] w_CompareDout;

    genvar cc;
    generate
        for(cc = 0; cc < SHR_DEPTH; cc = cc + 1) begin
            comparator_wrapper#(
                .VECTOR_WIDTH   (VECTOR_WIDTH),
                .BUS_WIDTH      (BUS_WIDTH)
            ) u_comparator_wr (
                .clk            (clk                            ),
                .rst            (rst                            ),
                .i_CntA         (r_CntDelayedOut_A[cc][DELAY]   ),
                .i_CntB         (r_CntDelayedOut_B[cc][DELAY]   ),
                .i_CntC         (w_Cnt_AnB[cc]                  ),
                .i_WrThreshold  (i_WrThreshold                  ),
                .i_Threshold    (i_Threshold                    ),
                .i_Valid        (w_PreStageOut_Valid[cc]        ),
                .o_Ready        (o_ComparatorReady              ),
                .o_ReadThreshold(o_ReadThreshold                ),
                .o_Dout         (w_CompareDout[cc]              )
            );
        end
    endgenerate


    // OUTPUT FIFO TREE
    localparam FIFO_DATA_WIDTH          = 2*VEC_ID_WIDTH;
    localparam FIFO_DATA_COUNT_WIDTH    = $clog2(FIFO_DATA_WIDTH);
    localparam FIFO_TREE_DEPTH          = $clog2(SHR_DEPTH) + 1;

    // CNT1 outputs are valid for 2 clk long --> FIFO write clock is half of
    // clk
    reg r_fifo_wr_clk;
    
    always @ (posedge clk)
    begin
        if(rst) begin
            r_fifo_wr_clk <= 1'b0;
        end else begin
            r_fifo_wr_clk <= ~r_fifo_wr_clk;
        end
    end

    wire [FIFO_TREE_DEPTH*SHR_DEPTH-1:0]    w_fifo_almost_empty                                 ;
    wire [FIFO_TREE_DEPTH*SHR_DEPTH-1:0]    w_fifo_almost_full                                  ;
    wire [FIFO_TREE_DEPTH*SHR_DEPTH-1:0]    w_fifo_data_valid                                   ;
    wire [FIFO_TREE_DEPTH*SHR_DEPTH-1:0]    w_fifo_dbiterr                                      ;
    wire [FIFO_DATA_WIDTH-1:0]              w_fifo_dout         [FIFO_TREE_DEPTH*SHR_DEPTH-1:0] ;
    wire [FIFO_TREE_DEPTH*SHR_DEPTH-1:0]    w_fifo_empty                                        ;
    wire [FIFO_TREE_DEPTH*SHR_DEPTH-1:0]    w_fifo_full                                         ;
    wire [FIFO_TREE_DEPTH*SHR_DEPTH-1:0]    w_fifo_overflow                                     ;
    wire [FIFO_TREE_DEPTH*SHR_DEPTH-1:0]    w_fifo_prog_empty                                   ;
    wire [FIFO_TREE_DEPTH*SHR_DEPTH-1:0]    w_fifo_prog_full                                    ;
    wire [FIFO_DATA_COUNT_WIDTH-1:0]        w_fifo_rd_data_count[FIFO_TREE_DEPTH*SHR_DEPTH-1:0] ;
    wire [FIFO_TREE_DEPTH*SHR_DEPTH-1:0]    w_fifo_rd_rst_busy                                  ;
    wire [FIFO_TREE_DEPTH*SHR_DEPTH-1:0]    w_fifo_sbiterr                                      ;
    wire [FIFO_TREE_DEPTH*SHR_DEPTH-1:0]    w_fifo_underflow                                    ;
    wire [FIFO_TREE_DEPTH*SHR_DEPTH-1:0]    w_fifo_wr_ack                                       ;
    wire [FIFO_DATA_COUNT_WIDTH-1:0]        w_fifo_wr_data_count[FIFO_TREE_DEPTH*SHR_DEPTH-1:0] ;
    wire [FIFO_TREE_DEPTH*SHR_DEPTH-1:0]    w_fifo_wr_rst_busy                                  ;
    wire [FIFO_DATA_WIDTH-1:0]              w_fifo_din          [FIFO_TREE_DEPTH*SHR_DEPTH-1:0] ;
    wire [FIFO_TREE_DEPTH*SHR_DEPTH-1:0]    w_fifo_injectdbiterr                                ;
    wire [FIFO_TREE_DEPTH*SHR_DEPTH-1:0]    w_fifo_injectsbiterr                                ;
    wire [FIFO_TREE_DEPTH*SHR_DEPTH-1:0]    w_fifo_rd_en                                        ;
    wire [FIFO_TREE_DEPTH*SHR_DEPTH-1:0]    w_fifo_rst                                          ;
    wire [FIFO_TREE_DEPTH*SHR_DEPTH-1:0]    w_fifo_sleep                                        ;
    wire [FIFO_TREE_DEPTH*SHR_DEPTH-1:0]    w_fifo_wr_clk                                       ;
    wire [FIFO_TREE_DEPTH*SHR_DEPTH-1:0]    w_fifo_wr_en                                        ;
                                        
    wire [FIFO_TREE_DEPTH*SHR_DEPTH-1:0]    w_FifoDin_Sel                                       ;

    genvar tt, uu;
    generate
        for(tt = 0; tt < FIFO_TREE_DEPTH; tt = tt + 1) begin
            for(uu = 0; uu < SHR_DEPTH; uu = uu + 1) begin
                localparam LOCAL_DEPTH = SHR_DEPTH/(2**(FIFO_TREE_DEPTH-1-tt));
                // xpm_fifo_sync: Synchronous FIFO
                // Xilinx Parameterized Macro, version 2023.2
                xpm_fifo_sync #(
                   .CASCADE_HEIGHT      (0                      ),
                   .DOUT_RESET_VALUE    ("0"                    ),
                   .ECC_MODE            ("no_ecc"               ),
                   .FIFO_MEMORY_TYPE    ("auto"                 ),
                   .FIFO_READ_LATENCY   (0                      ),
                   .FIFO_WRITE_DEPTH    (32                     ),
                   .FULL_RESET_VALUE    (0                      ),
                   .PROG_EMPTY_THRESH   (10                     ),
                   .PROG_FULL_THRESH    (12                     ),  // must be high enough so that data in the pipeline still fits
                   .RD_DATA_COUNT_WIDTH (FIFO_DATA_COUNT_WIDTH  ),
                   .READ_DATA_WIDTH     (FIFO_DATA_WIDTH        ),
                   .READ_MODE           ("fwft"                 ),
                   .SIM_ASSERT_CHK      (0                      ),
                   .USE_ADV_FEATURES    ("0707"                 ),
                   .WAKEUP_TIME         (0                      ),
                   .WRITE_DATA_WIDTH    (FIFO_DATA_WIDTH        ),
                   .WR_DATA_COUNT_WIDTH (FIFO_DATA_COUNT_WIDTH  )
                )
                u_fifo_tree_fifo (
                   .almost_empty     (w_fifo_almost_empty   [2**tt + uu]),
                   .almost_full      (w_fifo_almost_full    [2**tt + uu]),
                   .data_valid       (w_fifo_data_valid     [2**tt + uu]),
                   .dbiterr          (w_fifo_dbiterr        [2**tt + uu]),
                   .dout             (w_fifo_dout           [2**tt + uu]),
                   .empty            (w_fifo_empty          [2**tt + uu]),
                   .full             (w_fifo_full           [2**tt + uu]),
                   .overflow         (w_fifo_overflow       [2**tt + uu]),
                   .prog_empty       (w_fifo_prog_empty     [2**tt + uu]),
                   .prog_full        (w_fifo_prog_full      [2**tt + uu]),
                   .rd_data_count    (w_fifo_rd_data_count  [2**tt + uu]),
                   .rd_rst_busy      (w_fifo_rd_rst_busy    [2**tt + uu]),
                   .sbiterr          (w_fifo_sbiterr        [2**tt + uu]),
                   .underflow        (w_fifo_underflow      [2**tt + uu]),
                   .wr_ack           (w_fifo_wr_ack         [2**tt + uu]),
                   .wr_data_count    (w_fifo_wr_data_count  [2**tt + uu]),
                   .wr_rst_busy      (w_fifo_wr_rst_busy    [2**tt + uu]),
                   .din              (w_fifo_din            [2**tt + uu]),
                   .injectdbiterr    (w_fifo_injectdbiterr  [2**tt + uu]),
                   .injectsbiterr    (w_fifo_injectsbiterr  [2**tt + uu]),
                   .rd_en            (w_fifo_rd_en          [2**tt + uu]),
                   .rst              (w_fifo_rst            [2**tt + uu]),
                   .sleep            (w_fifo_sleep          [2**tt + uu]),
                   .wr_clk           (w_fifo_wr_clk         [2**tt + uu]),
                   .wr_en            (w_fifo_wr_en          [2**tt + uu])
                ); // End of xpm_fifo_sync_inst instantiation

                assign w_fifo_wr_clk[2**tt + uu] = r_fifo_wr_clk;
                assign w_fifo_rst   [2**tt + uu] = rst;

                // Pipeline output to first layer of FIFOs (compatible vector
                // IDs are conacatenated as output)
                // Upper levels of the FIFO tree take input from FIFOs on
                // previous levels, priorizing FIFOs that are closer to being
                // full.
                if(tt == FIFO_TREE_DEPTH-1) begin           // CNT1 output to lowest FIFO-level
                    assign w_fifo_din   [2**tt + uu]        = {r_ShrID_2_A[uu][DELAY+1], r_ShrID_2_B[uu][DELAY+1]};
                    assign w_fifo_wr_en [2**tt + uu]        = w_CompareDout[uu];
                end else if(uu < LOCAL_DEPTH) begin         // other FIFO levels
                    assign w_FifoDin_Sel[2**tt + uu]        = (w_fifo_rd_data_count[2**(tt+1) + 2*uu] > w_fifo_rd_data_count[2**(tt+1) + 2*uu+1]) ? 1'b1 : 1'b0;
                    assign w_fifo_din   [2**tt + uu]        = w_FifoDin_Sel[2**tt + uu] ? w_fifo_dout[2**(tt+1) + 2*uu] : w_fifo_dout[2**(tt+1) + 2*uu+1];
                    assign w_fifo_wr_en [2**tt + uu]        = w_FifoDin_Sel[2**tt + uu] ? ~w_fifo_empty[2**(tt+1) + 2*uu] : ~w_fifo_empty[2**(tt+1) + 2*uu+1];
                    assign w_fifo_rd_en [2**(tt+1) + 2*uu]  = w_FifoDin_Sel[2**tt + uu] ? ~w_fifo_full[2**tt + uu] : 1'b0;
                    assign w_fifo_rd_en [2**(tt+1) + 2*uu+1]= w_FifoDin_Sel[2**tt + uu] ? 1'b0 : ~w_fifo_full[2**tt + uu];
                end
            end
        end
    endgenerate

    // Connect the root of the FIFO-tree with IO ports
    assign o_IDPair_Out     = w_fifo_dout   [1];
    assign o_IDPair_Ready   = ~w_fifo_empty [1];
    assign w_fifo_rd_en[1]  = i_IDPair_Read;


endmodule

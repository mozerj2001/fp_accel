`ifndef TANIMOTO_TOP
`define TANIMOTO_TOP


`timescale 1ns / 1ps
`default_nettype none


// VECTOR WEIGHT CALCULATOR TOP MODULE
// Reads SubVectors from a FIFO (AXI-Stream), stores ref vectors and their calculated
// weight in an array of shiftregisters. Shifts other incoming vectors
// beside the ref vectors, calculates the weight of every ref_vector
// & compared_vector vector, then calculates CNT(ref)+CNT(comp)
// and compares it agains a threshold (precalculated with possible CNT(ref&comp) values).
// Vector IDs over the threshold are propagated through a FIFO-tree.
// (ID is the position in the database, so vec_cat counts input vectors.)
module tanimoto_top
    #(
        BUS_WIDTH           = 128,      // system bus data width
        VECTOR_WIDTH        = 920,
        GRANULE_WIDTH       = 6,        // width of the first CNT1 tree stage, 6 on Xilinx/AMD FPGA
        SHR_DEPTH           = 8,        // how many vectors this module is able to store as reference vectors
        VEC_ID_WIDTH        = 16,       // implicitly defines how wide vector counters need to be
        //
        SUB_VECTOR_NO       = $rtoi($ceil($itor(VECTOR_WIDTH)/$itor(BUS_WIDTH))),
        CNT_WIDTH           = $clog2(VECTOR_WIDTH),
        FIFO_TREE_DEPTH     = ($clog2(SHR_DEPTH) + 1)
    )(
        input wire                          clk,
        input wire                          rstn,

        // Vector stream
        input wire [BUS_WIDTH-1:0]          i_Vector,
        input wire                          i_Valid,
        input wire                          i_Last,

        // Comprator BRAM interface for thresholds
        input wire                          i_BRAM_Clk,
        input wire                          i_BRAM_Rst,  
        input wire [CNT_WIDTH-1:0]          i_BRAM_Addr,
        input wire [CNT_WIDTH-1:0]          i_BRAM_Din, 
        input wire                          i_BRAM_En,  
        input wire                          i_BRAM_WrEn,

        // Output ID stream
        input wire                          i_IDPair_Read,
        output wire                         o_Read,
        output wire                         o_IDPair_Ready,
        output wire [2*VEC_ID_WIDTH-1:0]    o_IDPair_Out,
        output wire                         o_IDPair_Last
    );

    // States
    localparam LOAD_REF     = 2'b00;
    localparam COMPARE      = 2'b01;
    localparam FLUSH        = 2'b10;
    localparam OVER         = 2'b11;
    // Delays
    localparam CNT1_DELAY   = $rtoi($ceil($log10($itor(BUS_WIDTH)/($itor(GRANULE_WIDTH)*3.0))/$log10(3.0))) + 3;
    localparam FLUSH_DELAY  = CNT1_DELAY + SHR_DEPTH*SUB_VECTOR_NO + CNT1_DELAY;      // flush time until FIFO tree is the only factor

    // SUB_VECTOR_COUNTER
    // Counts backwards due to SHR_A indexing considerations
    localparam SUB_VECTOR_CNTR_WIDTH = $clog2(SUB_VECTOR_NO);
    reg [SUB_VECTOR_CNTR_WIDTH-1:0] r_SubVectorCntr;

    always @ (posedge clk)
    begin
        if(!rstn) begin
            r_SubVectorCntr <= 0;
        end else if(w_CNT1_Valid && !w_HaltPipeline) begin
            r_SubVectorCntr <= r_SubVectorCntr - 1;
        end
    end

    // STATE MACHINE
    reg [1:0] r_State;
    wire      w_StartCompare;
    wire      w_StartFlush;
    wire      w_ProcessingOver;
    wire      w_ResetPipeline;

    assign w_StartCompare   = ( w_CNT1_New              &&
                               (w_CNT1_ID == SHR_DEPTH) &&
                                !w_HaltPipeline           );

    assign w_StartFlush     = (w_CNT1_Last && !w_HaltPipeline);
    
    assign w_ProcessingOver = ( r_State_Shr[SHR_DEPTH-1] == FLUSH   &&
                                w_PropagateControl                  &&
                                w_ComparationOver                   &&
                                w_FifoTreeEmpty                     );

    assign w_ResetPipeline  = ((r_State == OVER) && i_IDPair_Read);


    always @ (posedge clk)
    begin
        if(!rstn) begin
            r_State <= LOAD_REF;
        end else if(w_StartCompare) begin
            r_State <= COMPARE;
        end else if(w_StartFlush) begin
            r_State <= FLUSH;
        end else if(w_ProcessingOver) begin
            r_State <= OVER;
        end else if (w_ResetPipeline) begin
            r_State <= LOAD_REF;
        end
    end

    // VECTOR CONCATENATOR UNIT
    // If the total vector width is not divisable by BUS_WIDTH, the vec_cat
    // module ensures that vectors aren't mixed up, thus will receive correct
    // CNT1 values. Responsible for emitting read signals and splicing input.
    wire [BUS_WIDTH-1:0]    w_CatVector;
    wire                    w_CatValid;
    wire [VEC_ID_WIDTH-1:0] w_CatVecID;
    wire                    w_CatLast;

    vec_cat #(
        .BUS_WIDTH      (BUS_WIDTH      ),
        .VECTOR_WIDTH   (VECTOR_WIDTH   ),
        .VEC_ID_WIDTH   (VEC_ID_WIDTH   )
    ) u_vec_cat_0 (
        .clk        (clk            ),
        .rstn       (rstn           ),
        .up_Vector  (i_Vector       ),
        .up_Valid   (i_Valid        ),
        .up_Last    (i_Last         ),
        .up_Ready   (o_Read         ),
        .dn_Vector  (w_CatVector    ),
        .dn_VecID   (w_CatVecID     ),
        .dn_Valid   (w_CatValid     ),
        .dn_Last    (w_CatLast      ),
        .dn_Ready   (w_CNT1_Ready   )
    );


    // INPUT CNT1 UNIT
    // Calculates input vector weight to be loaded into CNT shiftregisters.
    wire [BUS_WIDTH-1:0]    w_CNT1_Vector;
    wire [VEC_ID_WIDTH-1:0] w_CNT1_ID;
    wire [CNT_WIDTH-1:0]    w_CNT1_Cnt;
    wire                    w_CNT1_Valid;
    wire                    w_CNT1_New;
    wire                    w_CNT1_Last;
    wire                    w_CNT1_Ready;

    cnt1 #(
        .VECTOR_WIDTH   (VECTOR_WIDTH   ),
        .BUS_WIDTH      (BUS_WIDTH      ),
        .SUB_VECTOR_NO  (SUB_VECTOR_NO  ),
        .GRANULE_WIDTH  (GRANULE_WIDTH  ),
        .VEC_ID_WIDTH   (VEC_ID_WIDTH   )
    ) u_cnt1_in (
        .clk            (clk                ),
        .rstn           (rstn               ),
        .up_Vector      (w_CatVector        ),
        .up_ID          (w_CatVecID         ),
        .up_Valid       (w_CatValid         ),
        .up_Last        (w_CatLast          ),
        .up_Ready       (w_CNT1_Ready       ),
        .dn_SubVector   (w_CNT1_Vector      ),
        .dn_ID          (w_CNT1_ID          ),
        .dn_Valid       (w_CNT1_Valid       ),
        .dn_Cnt         (w_CNT1_Cnt         ),
        .dn_CntNew      (w_CNT1_New         ),
        .dn_Last        (w_CNT1_Last        ),
        .dn_Ready       (~w_HaltPipeline    )
    );


    // VALID SHIFTREGISTER AND STATE SHIFTREGISTER
    // LOAD_REF: only shift valid vectors
    // COMPARE: Shift all subvectors, propagate state and 
    // valid gradually along the shiftregisters, so
    // the out cnt1s start counting at the appropriate time.
    reg  [SHR_DEPTH-1:0]    r_Valid_Shr;
    reg  [1:0]              r_State_Shr     [SHR_DEPTH-1:0];
    wire [SHR_DEPTH-1:0]    w_SHR2CNT1_Valid;
    wire [SHR_DEPTH-1:0]    w_SHR2CNT1_Last;
    wire [VEC_ID_WIDTH-1:0] w_SHR2CNT1_ID_A [SHR_DEPTH-1:0];
    wire [VEC_ID_WIDTH-1:0] w_SHR2CNT1_ID_B [SHR_DEPTH-1:0];

    // Propagate control signals and vectors when: a) vectors are compared, b) when the pipeline is being flushed
    wire w_PropagateControl;
    assign w_PropagateControl = (   ((r_State == COMPARE && w_CNT1_New) || (r_State == FLUSH)) &&
                                    !w_HaltPipeline );

    genvar vv;
    generate
        for(vv = 0; vv < SHR_DEPTH; vv = vv + 1) begin
            if(vv == 0) begin
                always @ (posedge clk)
                begin
                    if(!rstn) begin
                        r_Valid_Shr[vv] <= 1'b0;
                        r_State_Shr[vv] <= LOAD_REF;
                    end else if(w_PropagateControl) begin
                        r_Valid_Shr[vv] <= w_CNT1_Valid;
                        r_State_Shr[vv] <= r_State;
                    end
                end
            end else begin
                always @ (posedge clk)
                begin
                    if(!rstn) begin
                        r_Valid_Shr[vv] <= 1'b0;
                        r_State_Shr[vv] <= LOAD_REF;
                    end else if(w_PropagateControl) begin
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
    assign w_Shift_A = w_CNT1_Valid && (r_State == LOAD_REF);

    wire w_Shift_B;
    reg  r_Shift_B_Del;
    assign w_Shift_B = w_CNT1_Valid && (r_State > LOAD_REF);

    always @ (posedge clk)
    begin
        if(!rstn) begin
            r_Shift_B_Del <= 0;
        end else begin
            r_Shift_B_Del <= w_Shift_B;
        end
    end

    reg [BUS_WIDTH-1:0] r_Vector_Array_A[SHR_DEPTH-1:0][SUB_VECTOR_NO-1:0];
    reg [BUS_WIDTH-1:0] r_Vector_Array_B[SHR_DEPTH-1:0][SUB_VECTOR_NO-1:0];

    integer ii, jj;
    always @ (posedge clk)
    begin
        if(w_Shift_A) begin
            for(ii = 0; ii < SHR_DEPTH; ii = ii + 1) begin
                for(jj = 0; jj < SUB_VECTOR_NO; jj = jj + 1) begin
                    if(ii == 0 && jj == 0) begin
                        r_Vector_Array_A[ii][jj] <= w_CNT1_Vector;
                    end else if(jj == 0) begin
                        r_Vector_Array_A[ii][jj] <= r_Vector_Array_A[ii-1][SUB_VECTOR_NO-1];
                    end else begin
                        r_Vector_Array_A[ii][jj] <= r_Vector_Array_A[ii][jj-1];
                    end
                end
            end
        end else if(w_Shift_B) begin
            for(ii = 0; ii < SHR_DEPTH; ii = ii + 1) begin
                for(jj = 0; jj < SUB_VECTOR_NO; jj = jj + 1) begin
                    if(ii == 0 && jj == 0) begin
                        r_Vector_Array_B[ii][jj] <= w_CNT1_Vector;
                    end else if(jj == 0) begin
                        r_Vector_Array_B[ii][jj] <= r_Vector_Array_B[ii-1][SUB_VECTOR_NO-1];
                    end else begin
                        r_Vector_Array_B[ii][jj] <= r_Vector_Array_B[ii][jj-1];
                    end
                end
            end
        end
    end


    // AnB MUX
    // Select which SubVector of A is in an and gate with the current
    // B sub-vector in this stage of the pipeline.
    wire [BUS_WIDTH-1:0] w_SHR2CNT1_AnB[SHR_DEPTH-1:0];

    genvar mm;
    generate
        for(mm = 0; mm < SHR_DEPTH; mm = mm + 1) begin
            assign w_SHR2CNT1_AnB[mm] = r_Vector_Array_A[mm][r_SubVectorCntr] & r_Vector_Array_B[mm][0];
        end
    endgenerate


    // CNT SHIFTREGISTERS
    // Store CNT1 reslults from the input CNT1 unit in a LUT shiftregister.
    // r_State selects whether the results are from A or B vectors, similarly
    // to the VECTOR SHIFTREGISTERS.
    wire w_Shift_CntA;
    assign w_Shift_CntA = w_CNT1_New && (r_State == LOAD_REF);

    wire w_Shift_CntB;
    assign w_Shift_CntB = w_CNT1_New && (r_State == COMPARE);

    reg [CNT_WIDTH-1:0] r_Cnt_Array_A[SHR_DEPTH-1:0];
    reg [CNT_WIDTH-1:0] r_Cnt_Array_B[SHR_DEPTH-1:0];

    always @ (posedge clk)
    begin
        if(w_Shift_CntA) begin
            r_Cnt_Array_A[0] <= w_CNT1_Cnt;
            for(jj = 1; jj < SHR_DEPTH; jj = jj + 1) begin
                r_Cnt_Array_A[jj] <= r_Cnt_Array_A[jj-1];
            end
        end else if(w_Shift_CntB) begin
            r_Cnt_Array_B[0] <= w_CNT1_Cnt;
            for(jj = 1; jj < SHR_DEPTH; jj = jj + 1) begin
                r_Cnt_Array_B[jj] <= r_Cnt_Array_B[jj-1];
            end
        end
    end

    // ID SHIFTREGISTERS
    // Identical to CNT shiftregisters, they store the ID of each vector.
    // SHR0: Compensate the delay of the input cnt1.  [CNT1_DELAY]
    // SHR1: Store alongside the CNT value and sub_vectors.     [SHR_DEPTH]
    // SHR2: Compensate output cnt1 and comparison.   [CNT1_DELAY+2]
    //  (CNT1 delay + 2 clk for comparator addition and RAM activity)
    reg [VEC_ID_WIDTH-1:0]  r_ShrID_A [SHR_DEPTH-1:0];
    reg [VEC_ID_WIDTH-1:0]  r_ShrID_B [SHR_DEPTH-1:0];

    genvar ee;
    generate
        for(ee = 0; ee < SHR_DEPTH; ee = ee + 1) begin
            always @ (posedge clk)
            begin
                if(ee == 0) begin
                    if(w_CNT1_New) begin
                        if(r_State == LOAD_REF) begin
                            r_ShrID_A[ee] <= w_CNT1_ID;
                        end else begin
                            r_ShrID_B[ee] <= w_CNT1_ID;
                        end
                    end
                end else begin
                    if(w_CNT1_New) begin
                        if(r_State == LOAD_REF) begin
                            r_ShrID_A[ee] <= r_ShrID_A[ee-1];
                        end else begin
                            r_ShrID_B[ee] <= r_ShrID_B[ee-1];
                        end
                    end
                end
            end
        end
    endgenerate


    // CNT1 A&B
    // Calculates the weight of A&B vectors.
    wire [CNT_WIDTH-1:0]        w_AnB_CNT1_Cnt [SHR_DEPTH-1:0];
    wire [2*VEC_ID_WIDTH-1:0]   w_AnB_CNT1_ID  [SHR_DEPTH-1:0];
    wire [SHR_DEPTH-1:0]        w_AnB_CNT1_Valid;
    wire [SHR_DEPTH-1:0]        w_AnB_CNT1_New;
    wire [SHR_DEPTH-1:0]        w_AnB_CNT1_Last;
    wire [SHR_DEPTH-1:0]        w_PipelineReady;

    wire w_HaltPipeline;
    assign w_HaltPipeline = ~r_PipelineReadyTree[0][0];

    // Or-tree for pipeline ready
    reg [SHR_DEPTH-1:0] r_PipelineReadyTree[FIFO_TREE_DEPTH-1:0];

    genvar xx, yy;
    generate
        for(xx = 0; xx < FIFO_TREE_DEPTH; xx = xx + 1) begin
            for(yy = 0; yy < SHR_DEPTH; yy = yy + 1) begin
                localparam LOCAL_DEPTH = SHR_DEPTH/(2**(FIFO_TREE_DEPTH-1-xx));

                always @ (posedge clk) begin
                    if(xx == FIFO_TREE_DEPTH-1) begin
                        r_PipelineReadyTree[xx][yy] <= w_PipelineReady[yy];
                    end else if(yy < LOCAL_DEPTH) begin
                        r_PipelineReadyTree[xx][yy] <= r_PipelineReadyTree[xx+1][yy*2] || r_PipelineReadyTree[xx+1][yy*2+1];
                    end
                end
            end
        end
    endgenerate


    genvar kk;
    generate
        for(kk = 0; kk < SHR_DEPTH; kk = kk + 1) begin

            assign w_SHR2CNT1_ID_A[kk]  = r_ShrID_A[kk];
            assign w_SHR2CNT1_ID_B[kk]  = r_ShrID_B[kk];
            assign w_SHR2CNT1_Valid[kk] = r_Valid_Shr[kk] && (r_State_Shr[kk] > LOAD_REF) && r_Shift_B_Del; // valid every time there is a new subvector + the current vector is valid
            assign w_SHR2CNT1_Last[kk]  = (r_State_Shr[kk] == FLUSH) && w_PropagateControl;

            cnt1 #(
                .VECTOR_WIDTH   (VECTOR_WIDTH   ),
                .BUS_WIDTH      (BUS_WIDTH      ),
                .SUB_VECTOR_NO  (SUB_VECTOR_NO  ),
                .GRANULE_WIDTH  (GRANULE_WIDTH  ),
                .VEC_ID_WIDTH   (2*VEC_ID_WIDTH )
            ) u_cnt1_out (
                .clk            (clk                                        ),
                .rstn           (rstn                                       ),
                .up_Vector      (w_SHR2CNT1_AnB[kk]                         ),
                .up_ID          ({w_SHR2CNT1_ID_A[kk], w_SHR2CNT1_ID_B[kk]} ),
                .up_Valid       (w_SHR2CNT1_Valid[kk]                       ),
                .up_Last        (w_SHR2CNT1_Last[kk]                        ),
                .up_Ready       (w_PipelineReady[kk]                        ),
                .dn_SubVector   (                                           ),
                .dn_ID          (w_AnB_CNT1_ID[kk]                          ),
                .dn_Valid       (w_AnB_CNT1_Valid[kk]                       ),
                .dn_Cnt         (w_AnB_CNT1_Cnt[kk]                         ),
                .dn_CntNew      (w_AnB_CNT1_New[kk]                         ),
                .dn_Last        (w_AnB_CNT1_Last[kk]                        ),
                .dn_Ready       (~w_fifo_full[2**(FIFO_TREE_DEPTH-1) + kk]  )
            );
        end
    endgenerate

    // COMPARATOR MODULES
    // Compare CNT1 results to programmed threshold.
    // o_Dout == 1 --> Current output IDs are over the threshold, the result can be emitted.
    wire [SHR_DEPTH-1:0]        w_CompareDout;
    wire [SHR_DEPTH-1:0]        w_CompareValid;
    wire [SHR_DEPTH-1:0]        w_CompareLast;
    wire [2*VEC_ID_WIDTH-1:0]   w_CompareID[SHR_DEPTH-1:0];
    reg  [SHR_DEPTH-1:0]        r_CompareLastObserved;
    wire                        w_ComparationOver;

    assign w_ComparationOver = &r_CompareLastObserved;

    genvar cc;
    generate
        for(cc = 0; cc < SHR_DEPTH; cc = cc + 1) begin
            comparator#(
                .VECTOR_WIDTH   (VECTOR_WIDTH   ),
                .VEC_ID_WIDTH   (2*VEC_ID_WIDTH )
            ) u_comparator (
                .clk            (clk                                        ),
                .rstn           (rstn                                       ),
                .i_CntA         (r_CntDelayedOut_A[cc][CNT1_DELAY-1]        ),
                .i_CntB         (r_CntDelayedOut_B[cc][CNT1_DELAY-1]        ),
                .i_CntC         (w_AnB_CNT1_Cnt[cc]                         ),
                .i_BRAM_Clk     (i_BRAM_Clk                                 ),
                .i_BRAM_Rst     (i_BRAM_Rst                                 ),
                .i_BRAM_Addr    (i_BRAM_Addr                                ),
                .i_BRAM_Din     (i_BRAM_Din                                 ),
                .i_BRAM_En      (i_BRAM_En                                  ),
                .i_BRAM_WrEn    (i_BRAM_WrEn                                ),
                .i_Valid        (w_AnB_CNT1_New[cc] && w_AnB_CNT1_Valid[cc] ),
                .o_Valid        (w_CompareValid[cc]                         ),
                .i_Last         (w_AnB_CNT1_Last[cc]                        ),
                .o_Last         (w_CompareLast[cc]                          ),
                .o_Dout         (w_CompareDout[cc]                          ),
                .i_ID           (w_AnB_CNT1_ID[cc]                          ),
                .o_ID           (w_CompareID[cc]                            )
            );

            always @ (posedge clk)
            begin
                if(!rstn) begin
                    r_CompareLastObserved[cc] <= 1'b0;
                end else if(w_StartCompare) begin
                    r_CompareLastObserved[cc] <= 1'b0;
                end else if(w_CompareLast[cc]) begin
                    r_CompareLastObserved[cc] <= 1'b1;
                end
            end

        end
    endgenerate

    // CNT OUT CNT1_DELAY SHIFTREGISTER
    // CNT values read from the shiftregisters need to be delayed until the
    // corresponding CNT(A&B) is calculated, then emitted.
    reg [CNT_WIDTH-1:0] r_CntDelayedOut_A [SHR_DEPTH-1:0][CNT1_DELAY:0];
    reg [CNT_WIDTH-1:0] r_CntDelayedOut_B [SHR_DEPTH-1:0][CNT1_DELAY:0];

    genvar nn;
    genvar oo;
    generate
        for(nn = 0; nn < SHR_DEPTH; nn = nn + 1) begin
            for(oo = 0; oo <= CNT1_DELAY; oo = oo + 1) begin
                if(oo == 0) begin
                    always @ (posedge clk)
                    begin
                        if(w_SHR2CNT1_Valid[nn]) begin
                            r_CntDelayedOut_A[nn][oo] <= r_Cnt_Array_A[nn];     // required in case new ref vectors are loaded on the fly
                            r_CntDelayedOut_B[nn][oo] <= r_Cnt_Array_B[nn];
                        end
                    end
                end else begin
                    always @ (posedge clk)
                    begin
                        if(w_SHR2CNT1_Valid[nn]) begin
                            r_CntDelayedOut_A[nn][oo] <= r_CntDelayedOut_A[nn][oo-1];     // required in case new ref vectors are loaded on the fly
                            r_CntDelayedOut_B[nn][oo] <= r_CntDelayedOut_B[nn][oo-1];
                        end
                    end
                end
            end
        end
    endgenerate
    


    // OUTPUT FIFO TREE
    localparam FIFO_DATA_WIDTH          = 2*VEC_ID_WIDTH;
    localparam FIFO_DEPTH               = 32;
    localparam FIFO_DATA_COUNT_WIDTH    = $clog2(FIFO_DEPTH);
    localparam FIFO_NUM                 = (2**FIFO_TREE_DEPTH) - 1;     // binary tree node number

    // CNT1 outputs are valid for 2 clk long --> wr_en needs to be one clk
    // pulse wide.

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
                                        
    // reg for empty signals
    reg  [2**FIFO_TREE_DEPTH-1:1]           r_FifoEmpty                                         ;
    wire                                    w_FifoTreeEmpty                                     ;

    // Logic to decide which FIFO output to take forward into the next stage (Round-Robin)
    reg [FIFO_TREE_DEPTH*SHR_DEPTH-1:1]     r_PreviousSource                                    ;
    reg [FIFO_TREE_DEPTH*SHR_DEPTH-1:0]     w_FifoDin_Sel                                       ;

    genvar tt, uu;
    generate
        for(tt = 0; tt < FIFO_TREE_DEPTH; tt = tt + 1) begin
            for(uu = 0; uu < SHR_DEPTH; uu = uu + 1) begin
                localparam LOCAL_DEPTH = SHR_DEPTH/(2**(FIFO_TREE_DEPTH-1-tt));
                if(uu < LOCAL_DEPTH) begin
                    // xpm_fifo_sync: Synchronous FIFO
                    // Xilinx Parameterized Macro, version 2023.2
                    xpm_fifo_sync #(
                       .CASCADE_HEIGHT      (0                      ),
                       .DOUT_RESET_VALUE    ("0"                    ),
                       .ECC_MODE            ("no_ecc"               ),
                       .FIFO_MEMORY_TYPE    ("auto"                 ),
                       .FIFO_READ_LATENCY   (0                      ),
                       .FIFO_WRITE_DEPTH    (FIFO_DEPTH             ),
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

                    assign w_fifo_wr_clk[2**tt + uu] = clk;
                    assign w_fifo_rst   [2**tt + uu] = !rstn;

                    // Pipeline output to first layer of FIFOs (compatible vector
                    // IDs are conacatenated as output)
                    // Upper levels of the FIFO tree take input from FIFOs on
                    // previous levels in a Round-Robin fashion.
                    if(tt == FIFO_TREE_DEPTH-1) begin           // CNT1 output to lowest FIFO-level
                        assign w_fifo_din   [2**tt + uu]        = w_CompareID[uu];
                        assign w_fifo_wr_en [2**tt + uu]        = (w_CompareDout[uu] && w_CompareValid[uu]);
                    end else if(uu < LOCAL_DEPTH) begin         // other FIFO levels

                        always @ (w_fifo_empty[2**(tt+1) + 2*uu], w_fifo_empty[2**(tt+1) + 2*uu+1], r_PreviousSource[2**tt+uu]) begin
                            // Both upstream FIFOs have data --> read from the one that was not previously read from
                            if({ w_fifo_empty[2**(tt+1) + 2*uu], w_fifo_empty[2**(tt+1) + 2*uu+1] } == 2'b00) begin
                                w_FifoDin_Sel[2**tt+uu] = ~r_PreviousSource[2**tt+uu];
                            end
                            // Even upstream FIFO has data, the odd one doesn't
                            else if(~w_fifo_empty[2**(tt+1) + 2*uu]) begin
                                w_FifoDin_Sel[2**tt+uu] = 1'b0;
                            end
                            // Odd upstream FIFO has data, the even one doesn't
                            else if(~w_fifo_empty[2**(tt+1) + 2*uu+1]) begin
                                w_FifoDin_Sel[2**tt+uu] = 1'b1;
                            end
                            // Default value for when neither FIFO has valid data
                            else begin
                                w_FifoDin_Sel[2**tt+uu] = 1'b0;
                            end
                        end

                        assign w_fifo_din   [2**tt + uu]        = w_FifoDin_Sel[2**tt + uu] ? w_fifo_dout[2**(tt+1) + 2*uu+1] : w_fifo_dout[2**(tt+1) + 2*uu];
                        assign w_fifo_wr_en [2**tt + uu]        = (~w_fifo_empty[2**(tt+1) + 2*uu]) || (~w_fifo_empty[2**(tt+1) + 2*uu+1]);
                        // w_FifoDin_Sel == 0 selects even upstream FIFO, w_FifoDin_Sel == 1 select odd upstream FIFO
                        assign w_fifo_rd_en [2**(tt+1) + 2*uu]  = ~w_FifoDin_Sel[2**tt + uu];
                        assign w_fifo_rd_en [2**(tt+1) + 2*uu+1]= w_FifoDin_Sel[2**tt + uu];

                    end

                    // FIFO port tie-offs
                    assign w_fifo_sleep[2**tt + uu] = 1'b0;

                    always @(posedge clk)
                    begin
                        // intermediate reg for empty signals
                        r_FifoEmpty[2**tt + uu]         <= w_fifo_empty[2**tt + uu];
                        // track which FIFO was last read from in Round-Robin
                        r_PreviousSource[2**tt + uu]    <= w_FifoDin_Sel[2**tt + uu];
                    end

                end
            end
        end
    endgenerate

    assign w_FifoTreeEmpty = &r_FifoEmpty;

    // Connect the root of the FIFO-tree with IO ports
    assign o_IDPair_Out     = (r_State == OVER) ? 0 : w_fifo_dout[1];
    assign o_IDPair_Ready   = (r_State == OVER) ? 1'b1 : ~w_fifo_empty[1];
    assign w_fifo_rd_en[1]  = i_IDPair_Read;
    assign o_IDPair_Last    = (r_State == OVER);


endmodule // tanimoto_top

`endif // TANIMOTO_TOP

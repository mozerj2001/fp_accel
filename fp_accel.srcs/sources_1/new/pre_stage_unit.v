`timescale 1ns / 1ps
`default_nettype none

//
// This module implements the first stage of the pharmacophore fingerprint
// comparison hardware accelerator. The number of high bits in the input
// vector are counted by the CNT1 bit_cntr module, then stored in RAM.
// The vectors themselves are delayed via SHR, a lut_shr shiftregister,
// then stored in LUT RAM at the same address as the corresponding CNT
// result. Input vector size is configurable. Other constants, such as
// pipeline depth and delay length are all determined based on BUS_WIDTH
// and SUB_VECTOR_NO (how many input vectors make up a full vector).
//
//
//                                   --------        -------
//                                   |      |        | RAM |
//                 VECTOR  ########>>| CNT1 |######>>| CNT |######>> CNT_A
//                           #       |      |        |  A  |
//                           #       --------        -------
//                           #       -------         -------         
//                           #       |     |         | RAM |         
//                           ######>>| SHR |#######>>|     |######>> VECTOR_A
//                                   |     |         |  A  |
//                                   -------         -------
//          
//           


module pre_stage_unit
    #(
        BUS_WIDTH = 512,
        SUB_VECTOR_NO = 4,
        GRANULE_WIDTH = 6,
        MEMORY_DEPTH = 4,               // how many full vectors can be stored in the LUT RAM

        //
        OUTPUT_VECTOR_WIDTH = BUS_WIDTH*SUB_VECTOR_NO,
        BIT_NO_OUTPUT_WIDTH = $clog2(OUTPUT_VECTOR_WIDTH)
    )
    (
        input wire                      clk,
        input wire                      rst,
        input wire [BUS_WIDTH-1:0]      i_Vector,
        input wire                      i_Valid,
        output wire [OUTPUT_VECTOR_WIDTH-1:0]   o_Vector,
        output wire [BIT_NO_OUTPUT_WIDTH-1:0]   o_Cnt
    );

    localparam WORD_CNTR_WIDTH = 4;
    localparam DELAY = $clog2(BUS_WIDTH/(GRANULE_WIDTH*3))/$clog2(3) + 2;
    localparam BIT_CNTR_OUT_WIDTH = $clog2(OUTPUT_VECTOR_WIDTH);

    /////////////////////////////////////////////////////////////////////////////////////
    // DATA WORD COUNTER AND SHIFTREGISTER
    // --> count input vectors, signal last word of a full vector to the
    // bit_cntr_wrapper. Shr act as a select signal for the concatenation of
    // delayed input vectors.
    wire w_LastWordOfVector;
    reg [WORD_CNTR_WIDTH-1:0] r_WordCntr;
    reg [SUB_VECTOR_NO-1:0] r_WordShr;          // sel signal for sub-vector concatenation

    always @ (posedge clk)
    begin
        if(rst) begin
            r_WordCntr <= {WORD_CNTR_WIDTH{1'b1}};
        end else if(w_LastWordOfVector) begin
            r_WordCntr <= 0;
        end else if(i_Valid) begin
            r_WordCntr <= r_WordCntr + 1;
        end
    end

    assign w_LastWordOfVector = (r_WordCntr == (WORD_CNTR_WIDTH-1));

    always @ (posedge clk) begin
        if(rst) begin
            r_WordShr <= {1'b1, {(SUB_VECTOR_NO-1){1'b0}}};
        end else if(w_SumNew) begin
            r_WordShr <= {r_WordShr[SUB_VECTOR_NO-2:0], r_WordShr[SUB_VECTOR_NO-1]};
        end else if(w_SumValid) begin
            r_WordShr <= {r_WordShr[SUB_VECTOR_NO-2:0], r_WordShr[SUB_VECTOR_NO-1]};
        end
    end


    /////////////////////////////////////////////////////////////////////////////////////
    // BIT COUNTER MODULE
    wire [BIT_CNTR_OUT_WIDTH-1:0] w_Sum;
    wire w_SumValid;
    wire w_SumNew;

    bit_cntr_wrapper
    #(
        .VECTOR_WIDTH(BUS_WIDTH), 
        .GRANULE_WIDTH(GRANULE_WIDTH),
        .OUTPUT_WIDTH(BIT_CNTR_OUT_WIDTH)
    )
    bit_counter(
        .clk(clk),
        .rst(rst),
        .i_Vector(i_Vector),
        .i_Valid(i_Valid),
        .i_LastWordOfVector(w_LastWordOfVector),

        .o_Sum(w_Sum),
        .o_SumValid(w_SumValid),
        .o_SumNew(w_SumNew)        // o_Sum can be read
    );


    /////////////////////////////////////////////////////////////////////////////////////
    // ADDRESS COUNTER
    reg [$clog2(MEMORY_DEPTH)-1:0] r_AddressCntr;

    always @ (posedge clk)
    begin
        if(rst) begin
            r_AddressCntr <= 0;
        end else if(w_LastWordOfVector) begin
            r_AddressCntr <= r_AddressCntr + 1;
        end
    end

    /////////////////////////////////////////////////////////////////////////////////////
    // SHIFTREGISTER
    // --> delay input vector until the corresponding sum is calculated
    wire [BUS_WIDTH-1:0] w_DelayedSubVector;

    genvar jj;
    generate
        for(jj = 0; jj < BUS_WIDTH; jj = jj + 1) begin
            lut_shr#(
                .WIDTH(DELAY)
            ) 
            delay_shr(
                .clk(clk),
                .sh_en(i_Valid),
                .din(r_CatVector[jj]),
                .addr(),
                .q_msb(w_DelayedSubVector[jj]),
                .q_sel()
            );
        end
    endgenerate
   

    /////////////////////////////////////////////////////////////////////////////////////
    // VECTOR RAM
    // --> stores vectors concatenated from sub-vectors
    //lut_ram #(
    //    .WIDTH(OUTPUT_VECTOR_WIDTH),
    //    .DEPTH(MEMORY_DEPTH)
    //)
    //(
    //    .clk(clk),
    //    .we(),
    //    .addr(),
    //    .din(),
    //    .dout
    //);

    
    /////////////////////////////////////////////////////////////////////////////////////
    // WORD CASCADING LOGIC
    // --> concatenate delayed sub-vectors into the full vector in every word counter
    // cycle. The resulting vector is written to RAM for every CNT1 sum
    // calculated.
    reg [BUS_WIDTH-1:0] r_CatVector[SUB_VECTOR_NO-2:0];
    wire [OUTPUT_VECTOR_WIDTH-1:0] w_MemoryDin;

    genvar ii;
    generate
        for(ii = 0; ii < SUB_VECTOR_NO-1; ii = ii + 1) begin
            always @ (posedge clk) begin
                if(r_WordShr[ii]) begin
                    r_CatVector[ii] <= w_DelayedSubVector;
                end
            end

            assign w_MemoryDin[(ii*SUB_VECTOR_NO) +: BUS_WIDTH] = r_WordShr[ii];
        end
    endgenerate

    assign w_MemoryDin[(OUTPUT_VECTOR_WIDTH-1) -: BUS_WIDTH] = w_DelayedSubVector;



endmodule

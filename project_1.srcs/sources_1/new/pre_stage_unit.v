`timescale 1ns / 1ps
`default_nettype none

`include "./bit_cntr_wrapper.v"
`include "./lut_shr.v"

//
// This module implements the first stage of the pharmacophore fingerprint
// comparison hardware accelerator. The number of high bits in the input
// vector are counted by the CNT1 bit_cntr module.
// The vectors themselves are delayed via a lut_shr shiftregister.
// Input vector size is configurable. Other constants, such as
// pipeline depth and delay length are all determined based on BUS_WIDTH
// and SUB_VECTOR_NO (how many input vectors make up a full vector).
//
//
//                       --------     
//                       |      |     
//     VECTOR  ########>>| CNT1 |###########>> CNT_A
//               #       |      |     
//               #       --------     
//               #       -------                  
//               #       |     |                  
//               ########| SHR |############>> VECTOR_A
//                       |     |         
//                       -------         
//          
//           


module pre_stage_unit
    #(
        VECTOR_WIDTH        = 920,
        BUS_WIDTH           = 512,
        SUB_VECTOR_NO       = 2,
        GRANULE_WIDTH       = 6,

        //
        BIT_NO_OUTPUT_WIDTH = $clog2(VECTOR_WIDTH)
    )
    (
        input wire                              clk,
        input wire                              rst,
        input wire [BUS_WIDTH-1:0]              i_Vector,
        input wire                              i_Valid,
        output wire [BUS_WIDTH-1:0]             o_SubVector,
	    output wire				                o_Valid,
        output wire [BIT_NO_OUTPUT_WIDTH-1:0]   o_Cnt,
        output wire                             o_CntNew
    );

    localparam WORD_CNTR_WIDTH      = 4;
    localparam DELAY                = $rtoi($ceil($log10($itor(BUS_WIDTH)/($itor(GRANULE_WIDTH)*3.0))/$log10(3.0))) + 2;
    localparam BIT_CNTR_OUT_WIDTH   = $clog2(VECTOR_WIDTH);

    /////////////////////////////////////////////////////////////////////////////////////
    // DATA WORD COUNTER
    // --> count input vectors, signal last word of a full vector to the
    // bit_cntr_wrapper. Shr act as a select signal for the concatenation of
    // delayed input vectors.
    wire w_LastWordOfVector;
    reg [WORD_CNTR_WIDTH-1:0] r_WordCntr;

    always @ (posedge clk)
    begin
        if(rst) begin
            r_WordCntr <= 0;
        end else if(w_LastWordOfVector) begin
            r_WordCntr <= 0;
        end else if(i_Valid) begin
            r_WordCntr <= r_WordCntr + 1;
        end
    end

    assign w_LastWordOfVector = (r_WordCntr == SUB_VECTOR_NO-1);

    /////////////////////////////////////////////////////////////////////////////////////
    // BIT COUNTER MODULE
    wire [BIT_CNTR_OUT_WIDTH-1:0] w_Sum;
    wire w_SumValid;
    wire w_SumNew;

    bit_cntr_wrapper
    #(
        .VECTOR_WIDTH       (BUS_WIDTH          ), 
        .GRANULE_WIDTH      (GRANULE_WIDTH      ),
        .OUTPUT_WIDTH       (BIT_CNTR_OUT_WIDTH )
    )
    bit_counter(
        .clk                (clk                ),
        .rst                (rst                ),
        .i_Vector           (i_Vector           ),
        .i_Valid            (i_Valid            ),
        .i_LastWordOfVector (w_LastWordOfVector ),

        .o_Sum              (w_Sum              ),
        .o_SumValid         (w_SumValid         ),
        .o_SumNew           (w_SumNew           )        // o_Sum can be read
    );


    /////////////////////////////////////////////////////////////////////////////////////
    // SHIFTREGISTER
    // --> delay input vector as well as valid signal until the corresponding sum is calculated
    wire [BUS_WIDTH-1:0] w_DelayedSubVector;

    genvar jj;
    generate
        for(jj = 0; jj < BUS_WIDTH; jj = jj + 1) begin
            lut_shr #(
                .WIDTH  (DELAY                  )
            ) vector_shr (
                .clk    (clk                    ),
                .sh_en  (i_Valid                ),
                .din    (i_Vector[jj]           ),
                .addr   (                       ),
                .q_msb  (w_DelayedSubVector[jj] ),
                .q_sel  (                       )
            );
        end
    endgenerate

    lut_shr #(
	    .WIDTH      (DELAY      )
    ) valid_shr (
	    .clk		(clk        ),
	    .sh_en		(clk        ),
	    .din		(i_Valid    ),
	    .addr		(           ),
	    .q_msb		(o_Valid    ),
	    .q_sel		(           )
        );


    /////////////////////////////////////////////////////////////////////////////////////
    // ASSIGN OUTPUTS
    assign o_Cnt        = w_Sum;
    assign o_SubVector  = w_DelayedSubVector;
    assign o_CntNew     = w_SumNew;
    

endmodule

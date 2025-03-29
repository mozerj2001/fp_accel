`ifndef CNT1
`define CNT1

`timescale 1ns / 1ps
`default_nettype none

`include "lut_shr.v"
`include "bit_cntr.v"

//
//
//                       --------     
//                       |      |     
//     VECTOR  ########>>| CNT1 |###########>> CNT_A
//               #       |      |     
//               #       --------     
//               #       -------                  
//               #       |     |                  //               ########| SHR |############>> VECTOR_A
//                       |     |         
//                       -------         
//          
//           


module cnt1
    #(
        VECTOR_WIDTH        = 920,
        BUS_WIDTH           = 128,
        SUB_VECTOR_NO       = $ceil($itor(VECTOR_WIDTH)/$itor(BUS_WIDTH)),
        GRANULE_WIDTH       = 6,

        //
        CNT_WIDTH           = $clog2(VECTOR_WIDTH)
    )
    (
        input wire                              clk,
        input wire                              rstn,
        input wire [BUS_WIDTH-1:0]              i_Vector,
        input wire                              i_Valid,
        output wire                             o_Ready,
        output wire [BUS_WIDTH-1:0]             o_SubVector,
	    output wire				                o_Valid,
        output wire [CNT_WIDTH-1:0]             o_Cnt,
        output wire                             o_CntNew,
        input wire                              i_Ready
    );

    localparam WORD_CNTR_WIDTH      = $clog2(SUB_VECTOR_NO);
    localparam BIT_CNTR_OUT_WIDTH   = $clog2(BUS_WIDTH);
    localparam PAD_WIDTH            = CNT_WIDTH-BIT_CNTR_OUT_WIDTH;
    localparam DELAY                = $rtoi($ceil($log10($itor(BUS_WIDTH)/($itor(GRANULE_WIDTH)*3.0))/$log10(3.0))) + 2;

    /////////////////////////////////////////////////////////////////////////////////////
    // DATA WORD COUNTER
    // --> count input vectors, signal last word of a full vector to the
    // bit_cntr_wrapper. Shr act as a select signal for the concatenation of
    // delayed input vectors.
    wire                        w_LastWordOfVector;
    reg [WORD_CNTR_WIDTH-1:0]   r_WordCntr;
    wire                        w_ValidDel;

    always @ (posedge clk)
    begin
        if(!rstn) begin
            r_WordCntr <= 0;
        end else if(w_LastWordOfVector && i_Ready) begin
            r_WordCntr <= 0;
        end else if(w_ValidDel && i_Ready) begin
            r_WordCntr <= r_WordCntr + 1;
        end
    end

    assign w_LastWordOfVector = (r_WordCntr == SUB_VECTOR_NO-1);


    /////////////////////////////////////////////////////////////////////////////////////
    // BIT COUNTER 
    // --> count bits in the input vector
    wire [BIT_CNTR_OUT_WIDTH-1:0] w_Sum;

    bit_cntr
    #(
        .VECTOR_WIDTH   (BUS_WIDTH      ), 
        .GRANULE_WIDTH  (GRANULE_WIDTH  )
    ) u_bit_cntr (
        .clk            (clk            ),
        .rstn           (rstn           ),
        .i_Vector       (i_Vector       ),
        .i_CntrEn       (i_Ready        ),

        .o_Sum          (w_Sum          ) 
    );


    /////////////////////////////////////////////////////////////////////////////////////
    // ACCUMULATOR
    reg [CNT_WIDTH-1:0]     r_Accumulator;
    wire                    w_CntNew;   // current sum is the full weight of the last vector
    wire                    w_Valid;    // current counter output data is valid

    always @ (posedge clk)
    begin
        if(!rstn) begin
            r_Accumulator <= 0;
        end
        else if(w_CntNew && i_Ready) begin
            r_Accumulator <= w_Sum;
        end
        else if(w_Valid && i_Ready) begin
            r_Accumulator <= r_Accumulator + {{PAD_WIDTH{1'b0}}, w_Sum};
        end
    end


    /////////////////////////////////////////////////////////////////////////////////////
    // SHIFTREGISTER
    // --> delay input vector as well as valid signal and signal marking the last word
    // of the vector, until the corresponding sum is calculated and can be
    // read from the accumulator register.
    wire [BUS_WIDTH-1:0] w_DelayedSubVector;

    genvar jj;
    generate
        for(jj = 0; jj < BUS_WIDTH; jj = jj + 1) begin
            lut_shr #(
                .WIDTH  (DELAY                  )
            ) vector_shr (
                .clk    (clk                    ),
                .sh_en  (i_Valid && i_Ready     ),
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
	    .sh_en		(i_Ready    ),
	    .din		(i_Valid    ),
	    .addr		(3'b0       ),
	    .q_msb		(w_Valid    ),
	    .q_sel		(w_ValidDel )
        );

    lut_shr #(
	    .WIDTH      (DELAY      )
    ) last_word_shr (
	    .clk		(clk                    ),
	    .sh_en		(i_Ready                ),
	    .din		(w_LastWordOfVector     ),
	    .addr		(                       ),
	    .q_msb		(w_CntNew               ),
	    .q_sel		(                       )
        );


    /////////////////////////////////////////////////////////////////////////////////////
    // ASSIGN OUTPUTS
    assign o_Cnt        = r_Accumulator;
    assign o_SubVector  = w_DelayedSubVector;
    assign o_CntNew     = w_CntNew;
    assign o_Valid      = w_Valid;
    assign o_Ready      = i_Ready;
    

endmodule

`endif

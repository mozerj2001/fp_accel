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
        BUS_WIDTH           = 512,
        SUB_VECTOR_NO       = 2,
        GRANULE_WIDTH       = 6,

        //
        BIT_CNTR_OUT_WIDTH  = $clog2(VECTOR_WIDTH)
    )
    (
        input wire                              clk,
        input wire                              rstn,
        input wire [BUS_WIDTH-1:0]              i_Vector,
        input wire                              i_Valid,
        output wire [BUS_WIDTH-1:0]             o_SubVector,
	    output wire				                o_Valid,
        output wire [BIT_CNTR_OUT_WIDTH-1:0]    o_Cnt,
        output wire                             o_CntNew
    );

    localparam WORD_CNTR_WIDTH      = 4;
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
        end else if(w_LastWordOfVector) begin
            r_WordCntr <= 0;
        end else if(w_ValidDel) begin
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

        .o_Sum          (w_Sum          ) 
    );


    /////////////////////////////////////////////////////////////////////////////////////
    // ACCUMULATOR
    reg [BIT_CNTR_OUT_WIDTH-1:0]  r_Accumulator;
    wire                    w_CntNew;   // current sum is the full weight of the last vector
    wire                    w_Valid;    // current counter output data is valid

    always @ (posedge clk)
    begin
        if(!rstn) begin
            r_Accumulator <= 0;
        end
        else if(w_CntNew) begin
            r_Accumulator <= w_Sum;
        end
        else if(w_Valid) begin
            r_Accumulator <= r_Accumulator + w_Sum;
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
	    .addr		(0          ),
	    .q_msb		(w_Valid    ),
	    .q_sel		(w_ValidDel )
        );

    lut_shr #(
	    .WIDTH      (DELAY      )
    ) last_word_shr (
	    .clk		(clk                    ),
	    .sh_en		(clk                    ),
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
    

endmodule

`endif

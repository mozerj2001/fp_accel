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
        SUB_VECTOR_NO       = $rtoi($ceil($itor(VECTOR_WIDTH)/$itor(BUS_WIDTH))),
        GRANULE_WIDTH       = 6,
        VEC_ID_WIDTH        = 16,

        //
        CNT_WIDTH           = $clog2(VECTOR_WIDTH)
    )
    (
        input wire                              clk,
        input wire                              rstn,
        input wire [BUS_WIDTH-1:0]              up_Vector,
        input wire [VEC_ID_WIDTH-1:0]           up_ID,
        input wire                              up_Valid,
        input wire                              up_Last,
        output wire                             up_Ready,
        output wire [BUS_WIDTH-1:0]             dn_SubVector,
        output wire [VEC_ID_WIDTH-1:0]          dn_ID,
	    output wire				                dn_Valid,
        output wire [CNT_WIDTH-1:0]             dn_Cnt,
        output wire                             dn_CntNew,
        output wire                             dn_Last,
        input wire                              dn_Ready
    );

    localparam WORD_CNTR_WIDTH      = $clog2(SUB_VECTOR_NO);
    localparam BIT_CNTR_OUT_WIDTH   = $clog2(BUS_WIDTH)+1;
    localparam PAD_WIDTH            = CNT_WIDTH-BIT_CNTR_OUT_WIDTH;
    localparam CNT1_DELAY           = $rtoi($ceil($log10($itor(BUS_WIDTH)/($itor(GRANULE_WIDTH)*3.0))/$log10(3.0))) + 2;

    /////////////////////////////////////////////////////////////////////////////////////
    // DATA WORD COUNTER
    // --> count input vectors, signal last word of a full vector to the
    // bit_cntr_wrapper. Shr act as a select signal for the concatenation of
    // delayed input vectors.
    wire                        w_LastWordOfVector;
    reg [WORD_CNTR_WIDTH-1:0]   r_WordCntr;

    always @ (posedge clk)
    begin
        if(!rstn) begin
            r_WordCntr <= 0;
        end else if(w_LastWordOfVector && dn_Ready) begin
            r_WordCntr <= 0;
        end else if(r_DelayValid_SHR[CNT1_DELAY-1] && dn_Ready) begin
            r_WordCntr <= r_WordCntr + 1;
        end
    end

    assign w_LastWordOfVector = (r_WordCntr == SUB_VECTOR_NO-1) && r_DelayValid_SHR[CNT1_DELAY-1];


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
        .i_Vector       (up_Vector      ),
        .i_CntrEn       (dn_Ready       ),

        .o_Sum          (w_Sum          ) 
    );


    /////////////////////////////////////////////////////////////////////////////////////
    // ACCUMULATOR
    reg [CNT_WIDTH-1:0]     r_Accumulator;

    always @ (posedge clk)
    begin
        if(!rstn) begin
            r_Accumulator <= 0;
        end
        else if(w_LastWordOfVector && dn_Ready) begin
            r_Accumulator <= w_Sum;
        end
        else if(r_DelayValid_SHR[CNT1_DELAY-2] && dn_Ready) begin
            r_Accumulator <= r_Accumulator + {{PAD_WIDTH{1'b0}}, w_Sum};
        end
    end


    /////////////////////////////////////////////////////////////////////////////////////
    // SHIFTREGISTER
    // --> delay input vector as well as valid signal and signal marking the last word
    // of the vector, until the corresponding sum is calculated and can be
    // read from the accumulator register.
    reg [BUS_WIDTH-1:0]     r_DelaySubVector_SHR[CNT1_DELAY-1:0];
    reg [VEC_ID_WIDTH-1:0]  r_DelayID_SHR       [CNT1_DELAY-1:0];
    reg [CNT1_DELAY-1:0]    r_DelayValid_SHR;
    reg [CNT1_DELAY-1:0]    r_DelayLast_SHR;

    genvar ii;
    generate
        for(ii = 0; ii < CNT1_DELAY; ii = ii + 1) begin
            always @ (posedge clk)
            begin
                if(ii == 0) begin
                    if(dn_Ready) begin
                        r_DelaySubVector_SHR[ii] <= up_Vector;
                        r_DelayID_SHR       [ii] <= up_ID;
                        r_DelayValid_SHR    [ii] <= up_Valid;
                        r_DelayLast_SHR     [ii] <= up_Last;
                    end
                end else begin
                    if(dn_Ready) begin
                        r_DelaySubVector_SHR[ii] <= r_DelaySubVector_SHR[ii-1];
                        r_DelayID_SHR       [ii] <= r_DelayID_SHR       [ii-1];
                        r_DelayValid_SHR    [ii] <= r_DelayValid_SHR    [ii-1];
                        r_DelayLast_SHR     [ii] <= r_DelayLast_SHR     [ii-1];
                    end
                end
            end
        end
    endgenerate


    /////////////////////////////////////////////////////////////////////////////////////
    // ASSIGN OUTPUTS
    assign dn_Cnt       = r_Accumulator;
    assign dn_SubVector = r_DelaySubVector_SHR[CNT1_DELAY-1];
    assign dn_ID        = r_DelayID_SHR[CNT1_DELAY-1];
    assign dn_CntNew    = w_LastWordOfVector;
    assign dn_Valid     = r_DelayValid_SHR[CNT1_DELAY-1];
    assign dn_Last      = r_DelayLast_SHR[CNT1_DELAY-1];
    assign up_Ready     = dn_Ready;
    

endmodule

`endif

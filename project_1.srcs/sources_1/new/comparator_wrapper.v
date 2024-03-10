`timescale 1ns / 1ps
`default_nettype none

// COMPARATOR_WRAPPER
// This module is a wrapper to the comparator module in comparator.v.
// Its purpose is to hide RAM setup from external hardware. The only
// input needed are the desired threshold of (dis)similarity (i_Threshold)
// and the write signal for the threshold (i_WrThreshold). These need to be
// provided in the same clk.


module comparator_wrapper
    #(
        VECTOR_WIDTH    = 920,
        BUS_WIDTH       = 512,
        //
        CNT_WIDTH       = $clog2(VECTOR_WIDTH),
        ADDR_WIDTH      = CNT_WIDTH
    )(
        input wire                  clk,
        input wire                  rst,
        input wire [CNT_WIDTH-1:0]  i_CntA,
        input wire [CNT_WIDTH-1:0]  i_CntB,
        input wire [CNT_WIDTH-1:0]  i_CntC,
        input wire                  i_WrThreshold,      // Mux i_Addr onto the addr input of the RAM module
        input wire [CNT_WIDTH-1:0]  i_Threshold,
        input wire                  i_Valid,
        output wire                 o_Valid,
        output wire                 o_Ready,
        output wire                 o_Dout              // 1: over threshold, 0: under threshold
    );

    localparam LOAD_RAM = 1'b0;
    localparam COMPARE  = 1'b1;


    // STATE MACHINE
    // LOAD RAM: Load RAM with an address counter. (din: 1s or 0s)
    // COMPARE: Calculate CntA+CntB-CntC. o_Dout is 1 when under
    // the threshold, 0 when over the threshold.
    reg                     r_State;
    reg [CNT_WIDTH-1:0]     r_AddrCntr;
    reg [2*CNT_WIDTH-1:0]   r_Threshold;

    always @ (posedge clk)
    begin
        if(rst) begin
            r_State <= COMPARE;
        end else if((r_State == COMPARE) && i_WrThreshold) begin
            r_State <= LOAD_RAM;
            r_Threshold <= i_Threshold;
        end else if(r_AddrCntr == 2*VECTOR_WIDTH-1) begin
            r_State <= COMPARE;
        end
    end

    // ADDRESS COUNTER
    always @ (posedge clk)
    begin
        if(rst) begin
            r_AddrCntr <= 0;
        end else if(i_WrThreshold && (r_State == COMPARE)) begin
            r_AddrCntr <= 0;
        end else if(r_State == LOAD_RAM) begin
            r_AddrCntr <= r_AddrCntr + 1;
        end
    end

    // COMPARATOR
    //
    wire w_CompDin;
    assign w_CompDin = (r_AddrCntr <= r_Threshold) ? 1'b1 : 1'b0;

    comparator #(
        .VECTOR_WIDTH   (VECTOR_WIDTH           )
    ) u_comparator (
        .clk            (clk                    ),
        .rst            (rst                    ),
        .i_CntA         (i_CntA                 ),
        .i_CntB         (i_CntB                 ),
        .i_CntC         (i_CntC                 ),
        .i_RAM_Setup    (r_State == LOAD_RAM    ),
        .i_Addr         (r_AddrCntr             ),
        .i_Din          (w_CompDin              ),
        .i_WrEn         (r_State == LOAD_RAM    ),
        .o_Dout         (o_Dout                 )
    );


    reg [1:0] r_Valid;
    always @ (posedge clk)
    begin
        if(rst) begin
            r_Valid <= 2'b0;
        end else begin
            r_Valid[0] <= i_Valid;
            r_Valid[1] <= r_Valid[0];
        end
    end

    assign o_Valid = r_Valid[1];
    assign o_Ready = (r_State == COMPARE);


endmodule




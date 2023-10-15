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
        input wire                  i_WrThreshold,  // Mux i_Addr onto the addr input of the RAM module
        input wire [CNT_WIDTH-1:0]  i_Threshold,
        output wire                 o_Ready,
        output wire                 o_Dout          // 1: over threshold, 0: under threshold
    );

    localparam LOAD_RAM_0   = 2'b00;
    localparam LOAD_RAM_1   = 2'b01;
    localparam COMPARE      = 2'b10;

    // THRESHOLD REG
    // Register in which the threshold is stored when i_WrThreshold is
    // asserted.
    reg [CNT_WIDTH-1:0] r_Threshold;

    always @ (posedge clk)
    begin
        if(i_WrThreshold) begin
            r_Threshold <= i_Threshold;
        end
    end


    // STATE MACHINE
    // LOAD RAM: Load RAM with an address counter. (din: 1s or 0s)
    // COMPARE: Calculate CntA+CntB-CntC. o_Dout is 1 when under
    // the threshold, 0 when over the threshold.
    reg [1:0] r_State;
    reg [CNT_WIDTH-1:0] r_AddrCntr;

    always @ (posedge clk)
    begin
        if(rst) begin
            r_State <= COMPARE;
        end else if((r_State == COMPARE) && i_WrThreshold) begin
            r_State <= LOAD_RAM_0;
        end else if(r_AddrCntr == VECTOR_WIDTH) begin
            r_State <= COMPARE;
        end else if(r_AddrCntr == r_Threshold) begin
            r_State <= LOAD_RAM_1;
        end
    end

    // ADDRESS COUNTER
    always @ (posedge clk)
    begin
        if(rst) begin
            r_AddrCntr <= 0;
        end else if(i_WrThreshold && (r_State == COMPARE)) begin
            r_AddrCntr <= 0;
        end else if(r_State != COMPARE) begin
            r_AddrCntr <= r_AddrCntr + 1;
        end
    end

    // COMPARATOR
    wire w_CompDin;
    assign w_CompDin = (r_State == LOAD_RAM_0) ? 1'b1 : 1'b0;

    comparator #(
        .VECTOR_WIDTH   (VECTOR_WIDTH           ),
        .BUS_WIDTH      (BUS_WIDTH              )
    ) u_comparator (
        .clk            (clk                    ),
        .rst            (rst                    ),
        .i_CntA         (i_CntA                 ),
        .i_CntB         (i_CntB                 ),
        .i_CntC         (i_CntC                 ),
        .i_RAM_Setup    (r_State != COMPARE     ),
        .i_Addr         (r_AddrCntr             ),
        .i_Din          (w_CompDin              ),
        .i_WrEn         (r_State != COMPARE     ),
        .o_Dout         (o_Dout                 )
    );


    assign o_Ready = (r_State == COMPARE);


endmodule




`ifndef COMPARATOR_WRAPPER
`define COMPARATOR_WRAPPER

`timescale 1ns / 1ps
`default_nettype none


// COMPARATOR_WRAPPER
// This module is a wrapper to the comparator module in comparator.v.
// Its purpose is to hide RAM setup from external hardware. The only
// input needed is the desired threshold of (dis)similarity (i_Threshold).
//
// Configuration Behavior:
// 1. Mem[0] is always 0 --> if i_Threshold is 0, reset address to 0 and
// write 0.
// 2. If i_Threshold changes to non-zero, write it to the incremented address
// and increment the address counter.
// 3. If the r_AddrCntr is 0, always write 0.
// 4. On reset, set address to 0 and write 0.
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
        input wire [CNT_WIDTH:0]    i_Threshold,
        input wire                  i_Valid,
        output wire                 o_Valid,
        output wire                 o_Dout              // 1: over threshold, 0: under threshold
    );

    // THRESHOLD INPUT SHIFTREGISTER
    reg [CNT_WIDTH:0] r_Threshold[1:0];
    wire              w_WrEn;

    assign w_WrEn = (r_Threshold[0] != r_Threshold[1]) || rst;

    always @ (posedge clk) begin
        if(rst) begin
            r_Threshold[0] <= 0;
            r_Threshold[1] <= 0;
        end else begin
            r_Threshold[0] <= i_Threshold;
            r_Threshold[1] <= r_Threshold[0];
        end
    end

    // DATA INPUT MUX
    wire [CNT_WIDTH:0] w_Din;
    assign w_Din = rst ? 0 : i_Threshold;

    // ADDRESS COUNTER & ADDR INPUT MUX
    reg [CNT_WIDTH-1:0]     r_AddrCntr;
    wire [CNT_WIDTH-1:0]    w_Addr;

    assign w_Addr = (i_Threshold == 0 || rst) ? 0 : r_AddrCntr;
    // assign w_Addr = r_AddrCntr;

    always @ (posedge clk)
    begin
        if(rst) begin
            r_AddrCntr <= 1;
        end else if(i_Threshold == 0) begin
            r_AddrCntr <= 1;
        end else if(w_WrEn) begin
            r_AddrCntr <= r_AddrCntr + 1;
        end
    end

    comparator #(
        .VECTOR_WIDTH   (VECTOR_WIDTH           )
    ) u_comparator (
        .clk            (clk                    ),
        .rst            (rst                    ),
        .i_CntA         (i_CntA                 ),
        .i_CntB         (i_CntB                 ),
        .i_CntC         (i_CntC                 ),
        .i_Addr         (w_Addr                 ),
        .i_Din          (w_Din                  ),
        .i_WrEn         (w_WrEn                 ),
        .o_Dout         (o_Dout                 )
    );

    assign o_Valid = i_Valid;   // no delay in the underlying logic, keeping valid in the interface for now

endmodule

`endif

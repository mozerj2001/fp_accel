`timescale 1ns / 1ps
`default_nettype none

`include "block_ram_rd_1st.v"

// COMPARATOR
// Calculates CNT(A)+CNT(B)-CNT(C) to provide a (dis)similarity
// metric between A and B vectors, if C = A & B;.
// The result is used as an address into a 1 bit wide block RAM,
// that contains 1s up until the desired threshold address, then 0s.

module comparator
    #(
        VECTOR_WIDTH    = 920,
        //
        CNT_WIDTH       = $clog2(VECTOR_WIDTH),
        ADDR_WIDTH      = CNT_WIDTH
    )(
        input wire                  clk,
        input wire                  rst,
        input wire [CNT_WIDTH-1:0]  i_CntA,
        input wire [CNT_WIDTH-1:0]  i_CntB,
        input wire [CNT_WIDTH-1:0]  i_CntC,
        input wire                  i_RAM_Setup,    // Mux i_Addr onto the addr input of the RAM module

        // RAM I/O
        input wire [ADDR_WIDTH-1:0] i_Addr,
        input wire                  i_Din,
        input wire                  i_WrEn,
        output wire                 o_Dout          // 0: over threshold, 1: under threshold
    );

    // Similarity calc
    reg [CNT_WIDTH-1:0] r_Sum;

    always @ (posedge clk)
    begin
        if(rst) begin
            r_Sum <= 0;
        end else begin
            r_Sum <= i_CntA + i_CntB - i_CntC;
        end
    end

    // RAM storing Y/N values based on the configured threshold
    wire [ADDR_WIDTH-1:0] w_Addr;
    wire [ADDR_WIDTH-1:0] w_AddrSaturated;          // saturate address for better waveform visibility in non-valid cycles
    assign w_Addr = i_RAM_Setup ? i_Addr : r_Sum;
    assign w_AddrSaturated = (w_Addr > VECTOR_WIDTH) ? VECTOR_WIDTH : w_Addr;

    block_ram_rd_1st
    #(
        .DEPTH  (VECTOR_WIDTH+1),
        .WIDH   (1)
    ) u_result_ram (
        .clk    (clk),
        .we     (i_WrEn),
        .en     (1),
        .addr   (w_AddrSaturated),
        .din    (i_Din),
        .dout   (o_Dout)
    );


endmodule

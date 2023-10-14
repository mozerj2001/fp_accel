`timescale 1ns / 1ps
`default_nettype none

`include "block_ram_rd_1st.v"

module comparator
    #(
        VECTOR_WIDTH    = 920,
        BUS_WIDTH       = 512,
        //
        CNT_WIDTH       = $clog2(BUS_WIDTH*2),
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
        output wire                 o_Dout          // 1: over threshold, 0: under threshold
        
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
    assign w_Addr = i_RAM_Setup ? i_Addr : r_Sum;

    block_ram_rd_1st
    #(
        .DEPTH  (VECTOR_WIDTH+1),
        .WIDH   (1)
    ) u_result_ram (
        .clk    (clk),
        .we     (i_WrEn),
        .en     (1),
        .addr   (w_Addr),
        .din    (i_Din),
        .dout   (o_Dout)
    );


endmodule

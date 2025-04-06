`ifndef COMPARATOR
`define COMPARATOR

`timescale 1ns / 1ps
`default_nettype none

`include "block_ram_rd_1st.v"

// COMPARATOR
// Results that require division are stored in u_result_ram, at the address
// as the corresponding i_CntC value. The output of the RAM module is compared
// against the sum of i_CntA and i_CntB, which determines whether the Tanimoto
// dissimilarity is under the specified threshold.
// u_result_ram is configured by the wrapper, through the threshold top level
// port.
module comparator
    #(
        VECTOR_WIDTH    = 920,
        //
        CNT_WIDTH       = $clog2(VECTOR_WIDTH)
    )(
        input wire                  clk,
        input wire                  rstn,
        input wire [CNT_WIDTH-1:0]  i_CntA,
        input wire [CNT_WIDTH-1:0]  i_CntB,
        input wire [CNT_WIDTH-1:0]  i_CntC,

        // RAM I/O
        input wire                  i_BRAM_Clk,
        input wire                  i_BRAM_Rst,
        input wire [CNT_WIDTH-1:0]  i_BRAM_Addr,
        input wire [CNT_WIDTH-1:0]  i_BRAM_Din,
        input wire                  i_BRAM_En,
        input wire                  i_BRAM_WrEn,
        output wire                 o_Dout,
        
        // Valid signal
        input wire                  i_Valid,
        output wire                 o_Valid,

        // Last signal
        input wire                  i_Last,
        output wire                 o_Last
    );

    // Similarity calc
    reg [CNT_WIDTH:0]   r_Sum;

    always @ (posedge clk)
    begin
        if(!rstn) begin
            r_Sum   <= 0;
        end else begin
            r_Sum   <= i_CntA + i_CntB;
        end
    end


    wire [CNT_WIDTH-1:0] w_Addr;
    assign w_Addr = i_BRAM_WrEn ? i_BRAM_Addr : i_CntC;

    wire [CNT_WIDTH-1:0] w_Result;
    block_ram_rd_1st
    #(
        .DEPTH  (VECTOR_WIDTH+1 ),
        .WIDTH  (CNT_WIDTH      )
    ) u_result_ram (
        .clk    (clk        ),
        .we     (i_BRAM_WrEn),
        .en     (i_BRAM_En  ),
        .addr   (w_Addr     ),
        .din    (i_BRAM_Din ),
        .dout   (w_Result   )
    );

    // Valid delay register
    reg r_ValidDelay;
    reg r_LastDelay;

    always @ (posedge clk)
    begin
        r_ValidDelay <= i_Valid;
        r_LastDelay <= i_Last;
    end

    assign o_Dout = i_BRAM_WrEn ? 0 : (r_Sum >= {1'b0, w_Result});
    assign o_Valid = r_ValidDelay;
    assign o_Last = r_LastDelay;

endmodule

`endif

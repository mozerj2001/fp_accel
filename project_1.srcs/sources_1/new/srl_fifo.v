`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/30/2023 04:49:36 PM
// Design Name: 
// Module Name: srl_fifo
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module srl_fifo
#(
    parameter          WIDTH = 8,
    parameter          DEPTH = 32 
)(
    input              clk,
    input              rst,
    
    input              wr,
    input [WIDTH-1:0]  d,
    output             full,
    
    input              rd,
    output [WIDTH-1:0] q,
    output             empty
);

localparam CNT_W = $clog2(DEPTH);

integer i;

reg [WIDTH-1:0] data[DEPTH-1:0];
always @ (posedge clk)
if (wr)
    for (i=0; i<DEPTH; i=i+1)
        data[i] <= (i==0) ? d : data[i-1];
    
reg [CNT_W:0] cntr;
always @(posedge clk)
if (rst)
    cntr <= -1;
else if (rd & ~wr)
    cntr <= cntr - 1;
else if (~rd & wr)
    cntr <= cntr + 1;

reg full_ff;
always @(posedge clk)
if (rst)
    full_ff <= 1'b0;
else if (wr & ~rd & cntr==(DEPTH-2))
    full_ff <= 1'b1;
else if  (~wr & rd)
    full_ff <= 1'b0;

assign q     = data[cntr[CNT_W-1:0]];
assign empty = cntr[CNT_W];
assign full  = full_ff;



endmodule

`timescale 1ns / 1ps
`default_nettype none

module srl_fifo
#(
    parameter          WIDTH = 8,
    parameter          DEPTH = 32 
)(
    input wire              clk,
    input wire              rst,
    
    input wire              wr,
    input wire [WIDTH-1:0]  d,
    output wire             full,
    
    input wire              rd,
    output wire [WIDTH-1:0] q,
    output wire             empty
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

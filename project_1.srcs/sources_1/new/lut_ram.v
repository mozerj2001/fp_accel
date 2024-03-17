`ifndef LUT_RAM
`define LUT_RAM

`timescale 1ns / 1ps
`default_nettype none


// Parametrizable RAM module. Will be instantiated as LUT RAM in this project.
module lut_ram
    #(
        WIDTH = 512,
        DEPTH = 2
    )
    (
        input wire      clk,
        input wire      we,
        input wire [$clog2(WIDTH)-1:0]  addr,
        input wire [WIDTH-1:0]          din,
        output wire [WIDTH-1:0]         dout
    );

    reg [WIDTH-1:0] mem[DEPTH-1:0];

    always @ (posedge clk)
    begin
        if(we) begin
            mem[addr] <= din;
        end
    end

    assign dout = mem[addr];

endmodule

`endif
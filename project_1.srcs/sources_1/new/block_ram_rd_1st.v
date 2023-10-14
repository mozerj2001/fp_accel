`timescale 1ns / 1ps
`default_nettype none


module block_ram_rd_1st
    #(
        DEPTH = 1024,
        WIDTH = 1,
        //
        ADDR_WIDTH = $clog2(DEPTH)
    )(
        input wire                  clk,
        input wire                  we,
        input wire                  en,
        input wire [ADDR_WIDTH-1:0] addr,
        input wire [WIDTH-1:0]      din,
        output wire [WIDTH-1:0]     dout
    );

    reg [WIDTH-1:0] mem[DEPTH-1:0];
    reg [WIDTH-1:0] r_dout;

    always @ (posedge clk)
    begin
        if(en) begin
            if(we) begin
                mem[addr] = din;
            end
            r_dout = mem[addr];
        end
    end

    assign dout = r_dout;


endmodule

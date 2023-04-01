`timescale 1ns / 1ps
`default_nettype none

// Parametrizable, addressable LUT shiftregister module.

module lut_shr
    #(
        WIDTH = 64
    )
    (
        input wire clk, sh_en, din,
        input wire [$clog2(WIDTH)-1:0] addr,
        output wire q_msb, q_sel
    );

    reg [WIDTH-1:0] shr = WIDTH'b0;

    always @ (posedge clk)
    begin
        if(sh_en) begin
            shr <= {shr[WIDTH-2:0], din};
        end
    end

    assign q_msb = shr[WIDTH-1];
    assign q_sel = shr[addr];


endmodule

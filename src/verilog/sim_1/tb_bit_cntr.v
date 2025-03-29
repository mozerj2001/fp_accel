`timescale 1ns / 1ps
`default_nettype none

`include "../sources_1/bit_cntr.v"

// This is a testbench file for the parametrizable bit counter.

module tb_bit_cntr(

    );

    localparam CLK_PERIOD = 10;
    localparam HALF_CLK_PERIOD = 5;
    localparam VECTOR_WIDTH = 64;
    localparam GRANULE_WIDTH = 6;
    localparam GW3 = 3*GRANULE_WIDTH;
    localparam PIPELINE_DEPTH = $clog2(VECTOR_WIDTH/GW3)/$clog2(3);

    reg clk = 0;
    reg rstn;
    reg [VECTOR_WIDTH-1:0] vector;
    reg cntr_en;
    wire [(PIPELINE_DEPTH+1)*2:0] sum;

    // generate random input vectors
    integer i;
    always @ (posedge clk)
    begin
        if(rstn && cntr_en) begin
            for(i = 0; i*32 < VECTOR_WIDTH; i = i + 1) begin
                vector[i*32 +: 32] <= $urandom();
            end
        end
    end

    bit_cntr
    #(
        .VECTOR_WIDTH(VECTOR_WIDTH),
        .GRANULE_WIDTH(GRANULE_WIDTH)
    )
    uut(
        .clk        (clk),
        .rstn       (rstn),
        .i_Vector   (vector),
        .i_CntrEn   (cntr_en),
        .o_Sum      (sum)
    );

    // STIMULUS
    always
    begin
        clk <= ~clk;
        #HALF_CLK_PERIOD;
    end

    // RANDOMIZE CNTR_EN
    integer en_off;
    integer en_on ;

    initial begin
        en_off = $urandom_range(1, 5);
        en_on = $urandom_range(1, 10);
    end

    always begin
        cntr_en = 1'b1;
        #(en_on * CLK_PERIOD);
        cntr_en = 1'b0;
        #(en_off * CLK_PERIOD);
    end

    // RESET
    initial
    begin
        rstn <= 0;
        #CLK_PERIOD;
        rstn <= 1;
    end

endmodule

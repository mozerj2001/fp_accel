`timescale 1ns / 1ps
`default_nettype none

`include "../sources_1/comparator_wrapper.v"


module tb_comparator_wrapper(

    );

    localparam VECTOR_WIDTH     = 35;
    localparam BUS_WIDTH        = 20;
    localparam CNT_WIDTH        = $clog2(VECTOR_WIDTH);

    localparam CLK_PERIOD       = 10;
    localparam HALF_CLK_PERIOD  = CLK_PERIOD/2;


    reg rst = 1;
    reg clk = 0;

    reg [CNT_WIDTH-1:0] cnt_a = 0;
    reg [CNT_WIDTH-1:0] cnt_b = 0;
    reg [CNT_WIDTH-1:0] cnt_c = 0;

    reg [CNT_WIDTH:0]   threshold       = 0;
    reg                 wr_threshold    = 0;
    reg                 valid           = 0;

    wire out_valid;
    wire ready;
    wire dout;


    // DUT
    comparator_wrapper #(
        .VECTOR_WIDTH   (VECTOR_WIDTH   ),
        .BUS_WIDTH      (BUS_WIDTH      )
    ) u_dut (
        .clk            (clk            ),
        .rst            (rst            ),
        .i_CntA         (cnt_a          ),
        .i_CntB         (cnt_b          ),
        .i_CntC         (cnt_c          ),
        .i_Threshold    (threshold      ),
        .i_Valid        (valid          ),
        .o_Valid        (out_valid      ),
        .o_Dout         (dout           )          // 1: over threshold, 0: under threshold
    );

    // clk gen
    always begin 
        clk <= ~clk;
        #HALF_CLK_PERIOD;
    end


    initial begin
        #10;
        rst <= 1'b0;
        #500;
        wr_threshold <= 1'b1;
        #CLK_PERIOD;
        wr_threshold <= 1'b0;
        #550;
        wr_threshold <= 1'b1;
        #CLK_PERIOD;
        wr_threshold <= 1'b0;
    end


    // STIMULUS
    // load threshold RAM
    initial begin
        #50;
        rst <= 1'b0;
        #10;
        #CLK_PERIOD;
        for(integer i = 0; i < VECTOR_WIDTH; i = i + 1) begin
            threshold = threshold + 1;
            #CLK_PERIOD;
        end
        #600;
        threshold = 0;
        #CLK_PERIOD;
        for(integer i = 0; i < VECTOR_WIDTH; i = i + 1) begin
            threshold = threshold + 2;
            #CLK_PERIOD;
        end
    end

    // generate input data
    initial begin
        #500;
        #CLK_PERIOD;
        valid <= 1;
        // a+b=0 | c = 0 --> OK
        cnt_a = 0;
        cnt_b = 0;
        cnt_c = 0;
        #CLK_PERIOD;
        // a+b=7 | c = 3 --> OK
        cnt_a = 3;
        cnt_b = 4;
        cnt_c = 3;
        #CLK_PERIOD;
        // a+b=14 | c = 16 --> X
        cnt_a = 6;
        cnt_b = 8;
        cnt_c = 16;
        #CLK_PERIOD;
        // a+b=21 | c = 20 --> OK
        cnt_a = 20;
        cnt_b = 1;
        cnt_c = 20;
        #CLK_PERIOD;
        // a+b=28 | c = 32 --> X
        cnt_a = 11;
        cnt_b = 17;
        cnt_c = 32;
        #CLK_PERIOD;
        // a+b=35 | c = 35 --> OK
        cnt_a = 33;
        cnt_b = 2;
        cnt_c = 35;
        #CLK_PERIOD;
        // a+b=4 | c = 3 --> OK
        cnt_a = 2;
        cnt_b = 2;
        cnt_c = 3;
        #CLK_PERIOD;
        // a+b=33 | c = 0 --> OK
        cnt_a = 33;
        cnt_b = 0;
        cnt_c = 0;
        #CLK_PERIOD;
        // a+b=11 | c = 9 --> OK
        cnt_a = 10;
        cnt_b = 1;
        cnt_c = 9;
        #CLK_PERIOD;
        // a+b=11 | c = 32 --> X
        cnt_a = 7;
        cnt_b = 4;
        cnt_c = 32;
        #CLK_PERIOD;
        // a+b=11 | c = 1 --> OK
        cnt_a = 33;
        cnt_b = 2;
        cnt_c = 1;
        #CLK_PERIOD;
        valid <= 0;
    end

endmodule




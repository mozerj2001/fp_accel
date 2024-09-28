`timescale 1ns / 1ps
`default_nettype none

`include "../sources_1/comparator.v"


module tb_comparator(

    );

    localparam VECTOR_WIDTH    = 35;
    localparam BUS_WIDTH       = 20;
    localparam CNT_WIDTH        = $clog2(VECTOR_WIDTH);

    localparam CLK_PERIOD       = 10;
    localparam HALF_CLK_PERIOD  = CLK_PERIOD/2;

    localparam LOAD_RAM         = 1'b0;
    localparam DUT_TEST         = 1'b1;
    localparam THRESHOLD        = 24;

    //
    reg rst = 1;
    reg clk = 0;

    reg [CNT_WIDTH-1:0] cnt_a = 0;
    reg [CNT_WIDTH-1:0] cnt_b = 0;
    reg [CNT_WIDTH-1:0] cnt_c = 0;

    reg [CNT_WIDTH:0]   threshold = 0;
    reg                 wr_threshold = 0;

    reg     valid_in = 0;
    wire    valid_out;

    wire dout;


    // DUT
    // --> wired so that a RAM cell always contains the corresponding address
    comparator #(
        .VECTOR_WIDTH   (VECTOR_WIDTH   )
    ) u_dut (
        .clk            (clk            ),
        .rst            (rst            ),
        .i_CntA         (cnt_a          ),
        .i_CntB         (cnt_b          ),
        .i_CntC         (cnt_c          ),
        // BRAM
        .i_BRAM_Addr    (threshold      ),
        .i_BRAM_WrEn    (wr_threshold   ),
        .i_BRAM_Din     (threshold      ),
        .i_BRAM_En      (1'b1           ),
        .o_Dout         (dout           ),
        // Valid
        .i_Valid        (valid_in       ),
        .o_Valid        (valid_out      )
    );

    // clk gen
    always begin 
        clk <= ~clk;
        #HALF_CLK_PERIOD;
    end

    // STIMULUS
    // load threshold RAM
    initial begin
        #50;
        rst <= 1'b0;
        #10;
        wr_threshold <= 1;
        #CLK_PERIOD;
        for(integer i = 0; i < VECTOR_WIDTH; i = i + 1) begin
            threshold = threshold + 1;
            #CLK_PERIOD;
        end
        wr_threshold <= 0;
    end

    // generate input data
    initial begin
        #500;
        #CLK_PERIOD;
        valid_in = 1;
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
        valid_in = 0;
    end



endmodule


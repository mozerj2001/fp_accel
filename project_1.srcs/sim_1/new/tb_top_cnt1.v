`timescale 1ns / 1ps

`include "../../sources_1/new/top_cnt1.v"

module tb_top_cnt1(

    );

    localparam BUS_WIDTH        = 20;
    localparam VECTOR_WIDTH     = 35;
    localparam SUB_VECTOR_NO    = 2;
    localparam GRANULE_WIDTH    = 6;
    localparam SHR_DEPTH        = 4;

    localparam CLK_PERIOD       = 10;
    localparam HALF_CLK_PERIOD  = CLK_PERIOD/2;

    reg clk                     = 1'b0;
    reg rst                     = 1'b1;
    reg [BUS_WIDTH-1:0] vector;
    reg load_new_ref            = 0;

    wire [$clog2(VECTOR_WIDTH)-1:0] cnt_A;
    wire [$clog2(VECTOR_WIDTH)-1:0] cnt_B;
    wire [$clog2(VECTOR_WIDTH)-1:0] cnt_AB;
    wire valid_out;


    // FIFO SIGNALS
    reg f_write                 = 1'b0;
    reg [BUS_WIDTH-1:0] f_din   = 20'b0;
    wire f_read;
    wire [BUS_WIDTH-1:0] f_dout;
    wire f_full;
    wire f_empty;


    // TEST FIFO
    srl_fifo
    #(
        .WIDTH(BUS_WIDTH),
        .DEPTH(VECTOR_WIDTH)
    ) test_fifo (
        .clk    (clk),
        .rst    (rst),
        .wr     (f_write),
        .d      (f_din),
        .full   (f_full),
        .rd     (f_read),
        .q      (f_dout),
        .empty  (f_empty)
    );


    // DUT
    top_cnt1
    #(
        .BUS_WIDTH(BUS_WIDTH),
        .VECTOR_WIDTH(VECTOR_WIDTH),
        .SUB_VECTOR_NO(SUB_VECTOR_NO),
        .GRANULE_WIDTH(GRANULE_WIDTH),
        .SHR_DEPTH(SHR_DEPTH)
    ) uut (
        .clk                    (clk),
        .rst                    (rst),
        .i_Vector               (f_dout),
        .i_Valid                (~f_empty),
        .i_LoadNewRefVectors    (load_new_ref),
        .o_CntA                 (cnt_A),
        .o_CntB                 (cnt_B),
        .o_Cnt_AnB              (cnt_AB),
        .o_Valid                (valid_out),
        .o_Read                 (f_read)
    );

    always begin 
        clk <= ~clk;
        #HALF_CLK_PERIOD;
    end


    // FILL FIFO
    initial begin
        #50;
        f_write <= 1'b1;
        rst <= 1'b0;
        f_din <= 20'b11111111111111111111;
        #CLK_PERIOD;
        f_din <= 20'b11111111111111100110;
        #CLK_PERIOD;
        f_din <= 20'b01100110011001100110;
        #CLK_PERIOD;
        f_din <= 20'b01100110011111111111;
        #CLK_PERIOD;
        f_din <= 20'b11111111111111111111;
        #CLK_PERIOD;
        f_din <= 20'b11111010101010101010;
        #CLK_PERIOD;
        f_din <= 20'b10101010101010101010;
        #CLK_PERIOD;
        f_din <= 20'b11111111111111111111;
        #CLK_PERIOD;
        f_din <= 20'b11111111111111100110;
        #CLK_PERIOD;
        f_din <= 20'b01100110011001100110;
        #CLK_PERIOD;
        f_din <= 20'b01100110011111111111;
        #CLK_PERIOD;
        f_din <= 20'b11111111111111111111;
        #CLK_PERIOD;
        f_din <= 20'b11111010101010101010;
        #CLK_PERIOD;
        f_din <= 20'b10101010101010101010;
        #CLK_PERIOD;
        f_din <= 20'b11111111111111111111;
        f_write <= 1'b0;
        #CLK_PERIOD;
    end



endmodule

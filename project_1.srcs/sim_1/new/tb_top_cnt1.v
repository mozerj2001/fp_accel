`timescale 1ns / 1ps

`include "../../sources_1/new/top_cnt1.v"

module tb_top_cnt1(

    );

    localparam BUS_WIDTH        = 20;
    localparam VECTOR_WIDTH     = 35;
    localparam SUB_VECTOR_NO    = 2;
    localparam GRANULE_WIDTH    = 6;
    localparam SHR_DEPTH        = 4;
    localparam VEC_ID_WIDTH     = 8;
    localparam CNT_WIDTH        = $clog2(VECTOR_WIDTH);


    localparam CLK_PERIOD       = 10;
    localparam HALF_CLK_PERIOD  = CLK_PERIOD/2;

    reg clk                     = 1'b0;
    reg rst                     = 1'b1;
    reg [BUS_WIDTH-1:0] vector;
    reg load_new_ref            = 0;
    reg wr_threshold            = 0;
    wire cmp_rdy;
    wire th_read;


    // TEST FIFO SIGNALS
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
        .clk    (clk    ),
        .rst    (rst    ),
        .wr     (f_write),
        .d      (f_din  ),
        .full   (f_full ),
        .rd     (f_read ),
        .q      (f_dout ),
        .empty  (f_empty)
    );


    // TEST FIFO SIGNALS
    reg th_write                 = 1'b0;
    reg [CNT_WIDTH-1:0] th_din   = 50;
    wire th_read;
    wire [CNT_WIDTH-1:0] th_dout;
    wire th_full;
    wire th_empty;


    // THRESHOLD FIFO
    srl_fifo
    #(
        .WIDTH  (CNT_WIDTH      ),
        .DEPTH  (2*VECTOR_WIDTH )
    ) threshold_fifo (
        .clk    (clk            ),
        .rst    (rst            ),
        .wr     (th_write       ),
        .d      (th_din         ),
        .full   (th_full        ),
        .rd     (th_read        ),
        .q      (th_dout        ),
        .empty  (th_empty       )
    );


    // DUT
    wire                        id_pair_read;
    wire [2*VEC_ID_WIDTH-1:0]   id_pair_out;
    wire                        id_pair_ready;

    assign id_pair_read = id_pair_ready;

    top_cnt1
    #(
        .BUS_WIDTH      (BUS_WIDTH      ),
        .VECTOR_WIDTH   (VECTOR_WIDTH   ),
        .SUB_VECTOR_NO  (SUB_VECTOR_NO  ),
        .GRANULE_WIDTH  (GRANULE_WIDTH  ),
        .SHR_DEPTH      (SHR_DEPTH      ),
        .VEC_ID_WIDTH   (VEC_ID_WIDTH   )
    ) uut (
        .clk                    (clk            ),
        .rst                    (rst            ),
        .i_Vector               (f_dout         ),
        .i_Valid                (~f_empty       ),
        .i_WrThreshold          (wr_threshold   ),
        .i_Threshold            (th_dout        ),
        .i_LoadNewRefVectors    (load_new_ref   ),
        .i_IDPair_Read          (id_pair_read   ),
        .o_Read                 (f_read         ),
        .o_ReadThreshold        (th_read        ),
        .o_ComparatorReady      (cmp_rdy        ),
        .o_IDPair_Ready         (id_pair_ready  ),
        .o_IDPair_Out           (id_pair_out    )
    );

    always begin 
        clk <= ~clk;
        #HALF_CLK_PERIOD;
    end


    // FILL FIFOS
    initial begin
        #100;
        rst <= 1'b0;
        th_write <= 1'b1;
        #(CLK_PERIOD*2*VECTOR_WIDTH);
        th_write <= 1'b0;
        wr_threshold <= 1'b1;
        #CLK_PERIOD;
        wr_threshold <= 1'b0;
        #500;
        f_write <= 1'b1;
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
        f_write <= 1'b0;
        #CLK_PERIOD;
    end

    // 0 - 11111111111111111111111111111111111
    // 1 - 00110011001100110011001100110011001
    // 2 - 11111111111111111111111111111111111
    // 3 - 01010101010101010101010101010101010
    // 4 - 11111111111111111111111111111111111
    // 5 - 00110011001100110011001100110011001
    // 6 - 11111111111111111111111111111111111
    // 7 - 01010101010101010101010101010101010
    // 8 - 11111111111111111111111111111111111
    // 9 - 00110011001100110011001100110011001



endmodule

`timescale 1ns / 1ps
`default_nettype none

`include "../sources_1/cnt1.v"

// Testbench for the pre-stage unit.

module tb_cnt1(

    );

    // TEST PARAMETERS
    localparam CLK_PERIOD = 10;
    localparam HALF_CLK_PERIOD = 5;
    localparam T_RESET = 30;

    localparam BUS_WIDTH = 128;
    localparam VECTOR_WIDTH = 920;
    localparam GRANULE_WIDTH = 6;
    localparam SUB_VECTOR_NO = $ceil($itor(VECTOR_WIDTH)/$itor(BUS_WIDTH));
    localparam OUTPUT_VECTOR_WIDTH = BUS_WIDTH*SUB_VECTOR_NO;
    localparam BIT_NO_OUTPUT_WIDTH = $clog2(OUTPUT_VECTOR_WIDTH);

    // UUT
    reg                            clk = 0;
    reg                            rstn = 1;
    wire [BUS_WIDTH-1:0]           input_Vector;
    wire                           input_Valid;
    wire                           input_Ready;
    wire                           output_Valid;
    wire [BUS_WIDTH-1:0]           output_SubVector;
    wire [BIT_NO_OUTPUT_WIDTH-1:0] output_Cnt;
    wire                           output_CntNew;
    reg                            output_Ready;

    // generate random input vectors
    integer i;
    always @ (posedge clk)
    begin
        if(rstn && ~f_full) begin
            for(i = 0; i*32 < VECTOR_WIDTH; i = i + 1) begin
                f_din[i*32 +: 32] <= $urandom();
            end

            f_write <= 1'b1;
        end else begin
            f_write <= 1'b0;
        end
    end

    // TEST FIFO
    reg                     f_write;
    reg [BUS_WIDTH-1:0]     f_din;
    wire                    f_full;
    wire                    f_read;
    wire [BUS_WIDTH-1:0]    f_dout;
    wire                    f_empty;

    srl_fifo
    #(
        .WIDTH  (BUS_WIDTH      ),
        .DEPTH  (VECTOR_WIDTH   )
    ) test_fifo (
        .clk    (clk        ),
        .rstn   (rstn       ),
        .wr     (f_write    ),
        .d      (f_din      ),
        .full   (f_full     ),
        .rd     (f_read     ),
        .q      (f_dout     ),
        .empty  (f_empty    )
    );

    assign f_read = input_Ready;
    assign input_Vector = f_dout;
    assign input_Valid = ~f_empty;

    cnt1#(
        .VECTOR_WIDTH   (VECTOR_WIDTH   ),
        .BUS_WIDTH      (BUS_WIDTH      ),
        .GRANULE_WIDTH  (GRANULE_WIDTH  )
    )
    uut(
        .clk            (clk                ),
        .rstn           (rstn               ),
        .up_Vector      (input_Vector       ),
        .up_Valid       (input_Valid        ),
        .up_Ready       (input_Ready        ),
        .dn_SubVector   (output_SubVector   ),
        .dn_Valid       (output_Valid       ),
        .dn_Cnt         (output_Cnt         ),
        .dn_CntNew      (output_CntNew      ),
        .dn_Ready       (output_Ready       )
    );

    // STIMULUS
    always
    begin
        clk <= ~clk;
        #HALF_CLK_PERIOD;
    end

    // RANDOMIZE output_Ready
    integer en_off;
    integer en_on ;

    initial begin
        en_off = $urandom_range(1, 5);
        en_on = $urandom_range(1, 10);
    end

    always begin
        output_Ready = 1'b1;
        #(en_on * CLK_PERIOD);
        output_Ready = 1'b0;
        #(en_off * CLK_PERIOD);
    end

    initial
    begin
        #T_RESET;
        rstn <= 0;
        #T_RESET;
        rstn <= 1;
    end


endmodule

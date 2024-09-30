`timescale 1ns / 1ps
`default_nettype none


module tb_srl_fifo #()();


    localparam WIDTH = 4;
    localparam DEPTH = 16;
    localparam CNT_W = $clog2(DEPTH);

    // TEST PARAMETERS
    localparam CLK_PERIOD = 10;
    localparam HALF_CLK_PERIOD = 5;
    localparam T_RESET = 30;

    reg                 clk     = 0;
    reg                 rstn    = 0;
    reg                 wr      = 0;
    reg [WIDTH-1:0]     din     = 0;
    reg                 rd      = 0;

    wire                full;
    wire [WIDTH-1:0]    q;
    wire [CNT_W:0]      item_no;
    wire                empty;


    // DUT
    srl_fifo
    #(
        .WIDTH      (WIDTH      ),
        .DEPTH      (DEPTH      ),
        .CNT_W      (CNT_W      )
    ) u_dut (
        .clk        (clk        ),
        .rstn       (rstn       ),
        .wr         (wr         ),
        .d          (din        ),
        .full       (full       ),
        .rd         (rd         ),
        .q          (q          ),
        .item_no    (item_no    ),
        .empty      (empty      )
    );


    // STIMULUS
    always
    begin
        clk <= ~clk;
        #HALF_CLK_PERIOD;
    end

    always @ (posedge clk)
    begin
        if(!rstn) begin
            din <= 0;
        end else begin
            din <= din + 1;
        end
    end

    initial begin
        #T_RESET;
        rstn <= 1'b1;
        #T_RESET;
        wr <= 1'b1;
        #(CLK_PERIOD*6);
        rd <= 1'b1;
        #(CLK_PERIOD*5);
        wr <= 1'b0;
        #(CLK_PERIOD*3);
        rd <= 1'b0;
    end






endmodule

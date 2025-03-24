`timescale 1ns / 1ps

`include "../sources_1/srl_fifo.v"
`include "../sources_1/vec_cat.v"

module tb_vec_cat(

    );

    localparam BUS_WIDTH        = 96;
    localparam VECTOR_WIDTH     = 128;
    localparam VEC_ID_WIDTH     = 8;

    localparam REF_VEC_NO       = 8;
    localparam CMP_VEC_NO       = 128;

    localparam CLK_PERIOD       = 10;
    localparam HALF_CLK_PERIOD  = CLK_PERIOD/2;

    reg clk = 1'b0;
    reg rstn = 1'b0;
    reg [BUS_WIDTH-1:0] vector;
    reg valid = 1'b0;
    wire [VEC_ID_WIDTH-1:0] vec_id;
    wire [BUS_WIDTH-1:0] cat_vector;
    wire cat_valid;
    wire cat_last;

    // FIFO SIGNALS
    reg [BUS_WIDTH-1:0] f_din   = {BUS_WIDTH{1'b0}};
    wire f_read;
    wire [BUS_WIDTH-1:0] f_dout;
    wire f_full;
    wire f_empty;

    reg f_write_d;
    always @ (posedge clk)
    begin
        f_write_d <= !state;
    end

    // TEST FIFO
    srl_fifo
    #(
        .WIDTH  (BUS_WIDTH      ),
        .DEPTH  (VECTOR_WIDTH   )
    ) test_fifo (
        .clk    (clk        ),
        .rstn   (rstn       ),
        .wr     (f_write_d  ),
        .d      (f_din      ),
        .full   (f_full     ),
        .rd     (f_read     ),
        .q      (f_dout     ),
        .empty  (f_empty    )
    );



    // DUT
    vec_cat
    #(
        .BUS_WIDTH      (BUS_WIDTH      ),
        .VECTOR_WIDTH   (VECTOR_WIDTH   ),
        .VEC_ID_WIDTH   (VEC_ID_WIDTH   )
    ) uut(
        .clk        (clk                                    ),
        .rstn       (rstn                                   ),
        .i_Vector   (f_dout                                 ),
        .i_Valid    ((~f_empty && !state)                   ),
        .i_Last     ((vec_cnt == REF_VEC_NO + CMP_VEC_NO)   ),
        .o_Vector   (cat_vector                             ),
        .o_VecID    (vec_id                                 ),
        .o_Valid    (cat_valid                              ),
        .o_Read     (f_read                                 ),
        .o_Last     (cat_last                               )
    );

    always begin 
        clk <= ~clk;
        #HALF_CLK_PERIOD;
    end

    // FILL FIFO
    integer scan;
    reg [BUS_WIDTH-1:0] vec;

    // generate random input vectors
    integer ii;
    always @ (posedge clk)
    begin
        if(!state) begin
            for(ii = 0; ii*32 < VECTOR_WIDTH; ii = ii + 1) begin
                f_din[ii*32 +: 32] <= $urandom();
            end
        end
    end

    // COUNT INPUT VECTORS
    reg [15:0] vec_cnt;
    wire state;

    assign state = (vec_cnt >= REF_VEC_NO + CMP_VEC_NO) && !rstn;

    always @ (posedge clk)
    begin
        if(!rstn) begin
            vec_cnt <= 0;
        end else begin
            vec_cnt <= vec_cnt + 1;
        end
    end

    // PROGRAM CMP_VEC_NO REGISTER
    reg [VEC_ID_WIDTH-1:0]  cmp_vec_no = CMP_VEC_NO;
    reg                     cmp_vec_no_valid = 0;
    wire cmp_vec_no_wack;
    initial begin
        wait(rstn);

    end

    // RESET
    initial begin
        #50;
        rstn <= 1'b1;
        cmp_vec_no_valid <= 1'b1;
        #CLK_PERIOD;
        cmp_vec_no_valid <= 1'b0;

        #4000;

        $finish;
    end


endmodule

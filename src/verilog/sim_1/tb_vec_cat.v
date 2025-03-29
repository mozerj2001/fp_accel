`timescale 1ns / 1ps

`include "../sources_1/srl_fifo.v"
`include "../sources_1/vec_cat.v"

module tb_vec_cat(

    );

    localparam BUS_WIDTH        = 128;
    localparam VECTOR_WIDTH     = 920;
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
    reg  cat_ready = 1'b0;

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
    ) dut(
        .clk        (clk                                    ),
        .rstn       (rstn                                   ),
        .up_Vector  (f_dout                                 ),
        .up_Valid   ((~f_empty && !state)                   ),
        .up_Last    ((vec_cnt == REF_VEC_NO + CMP_VEC_NO)   ),
        .up_Ready   (f_read                                 ),
        .dn_Vector  (cat_vector                             ),
        .dn_VecID   (vec_id                                 ),
        .dn_Valid   (cat_valid                              ),
        .dn_Last    (cat_last                               ),
        .dn_Ready   (cat_ready                              )
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

    // RANDOMIZE READY

    integer ready_off;
    integer ready_on ;

    initial begin
        ready_off = $urandom_range(5);
        ready_on = $urandom_range(10);
    end

    always begin
        cat_ready = 1'b1;
        #(ready_on * CLK_PERIOD);
        cat_ready = 1'b0;
        #(ready_off * CLK_PERIOD);
    end

    // RESET
    initial begin
        #50;
        rstn <= 1'b1;
        #6000;
        $finish;
    end


endmodule

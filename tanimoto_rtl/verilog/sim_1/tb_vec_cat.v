`timescale 1ns / 1ps

`include "../sources_1/srl_fifo.v"
`include "../sources_1/vec_cat.v"

module tb_vec_cat(

    );

    localparam BUS_WIDTH        = 96;
    localparam VECTOR_WIDTH     = 128;
    localparam VEC_ID_WIDTH     = 8;

    localparam CLK_PERIOD       = 10;
    localparam HALF_CLK_PERIOD  = CLK_PERIOD/2;

    reg clk = 1'b0;
    reg rst = 1'b1;
    reg [BUS_WIDTH-1:0] vector;
    reg valid = 1'b0;
    wire [VEC_ID_WIDTH-1:0] vec_id;
    wire [BUS_WIDTH-1:0] cat_vector;
    wire cat_valid;

    // FIFO SIGNALS
    reg f_write                 = 1'b0;
    reg [BUS_WIDTH-1:0] f_din   = {BUS_WIDTH{1'b0}};
    wire f_read;
    wire [BUS_WIDTH-1:0] f_dout;
    wire f_full;
    wire f_empty;

    reg f_write_d;
    always @ (posedge clk)
    begin
        f_write_d <= f_write;
    end

    // TEST FIFO
    srl_fifo
    #(
        .WIDTH  (BUS_WIDTH      ),
        .DEPTH  (VECTOR_WIDTH   )
    ) test_fifo (
        .clk    (clk        ),
        .rst    (rst        ),
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
        .clk        (clk        ),
        .rst        (rst        ),
        .i_Vector   (f_dout     ),
        .i_Valid    (~f_empty   ),
        .o_Vector   (cat_vector ),
        .o_VecID    (vec_id     ),
        .o_Valid    (cat_valid  ),
	    .o_Read     (f_read     )
    );

    always begin 
        clk <= ~clk;
        #HALF_CLK_PERIOD;
    end

    // FILL FIFO
    integer fp_vec;
    integer fp_cat;
    integer scan;
    reg [BUS_WIDTH-1:0] vec;
    initial begin
        fp_vec = $fopen("/home/jozmoz01/Documents/fp_accel/tanimoto_rtl/test_vectors.dat", "r");
        if(fp_vec == 0) begin
            $display("File containing test vectors was not found...");
            $finish;
        end

        fp_cat = $fopen("/home/jozmoz01/Documents/fp_accel/tanimoto_rtl/vec_cat_result.txt", "w");
        if(fp_cat == 0) begin
            $display("Output file could not be opened...");
            $finish;
        end
    end

    reg state = 1'b1;
    always @ (posedge clk)
    begin
        if(~rst & f_write) begin
            scan = $fscanf(fp_vec, "%h\n", vec);
            if(!$feof(fp_vec)) begin
                f_din <= vec;
            end else begin
                $display("End of input file reached!");
            end
        end

        if(cat_valid) begin
            state <= ~state;

            if(state) begin
                $fwrite(fp_cat, "%h", cat_vector);
            end else begin
                $fwrite(fp_cat, "%h\n", cat_vector);
            end
        end
    end

    initial begin
        #50;
        f_write <= 1'b1;
        rst <= 1'b0;

        #3500;

        f_write <= 1'b0;

        #50;

        $fclose(fp_vec);
        $fclose(fp_cat);
        $finish;
    end


endmodule

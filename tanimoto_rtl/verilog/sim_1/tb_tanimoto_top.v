`timescale 1ns / 1ps

`include "../sources_1/tanimoto_top.v"

module tb_tanimoto_top(

    );

    localparam BUS_WIDTH        = 512;
    localparam VECTOR_WIDTH     = 920;
    localparam SUB_VECTOR_NO    = 2;
    localparam GRANULE_WIDTH    = 6;
    localparam SHR_DEPTH        = 32;
    localparam VEC_ID_WIDTH     = $clog2(VECTOR_WIDTH);
    localparam CNT_WIDTH        = $clog2(VECTOR_WIDTH);


    localparam CLK_PERIOD       = 10;
    localparam HALF_CLK_PERIOD  = CLK_PERIOD/2;

    reg clk                         = 1'b0;
    reg rst                         = 1'b1;
    reg [BUS_WIDTH-1:0] vector;
    wire cmp_rdy;

    reg [CNT_WIDTH:0]   threshold = 0;
    reg [CNT_WIDTH-1:0] threshold_addr = 0;
    reg                 wr_threshold;


    // TEST FIFO SIGNALS
    reg f_write                 = 1'b0;
    reg [BUS_WIDTH-1:0] f_din   = {BUS_WIDTH{1'b0}};
    wire f_read;
    wire [BUS_WIDTH-1:0] f_dout;
    wire f_full;
    wire f_empty;


    // TEST FIFO
    srl_fifo
    #(
        .WIDTH  (BUS_WIDTH      ),
        .DEPTH  (VECTOR_WIDTH   )
    ) test_fifo (
        .clk    (clk            ),
        .rst    (rst            ),
        .wr     (f_write_d      ),
        .d      (f_din          ),
        .full   (f_full         ),
        .rd     (f_read         ),
        .q      (f_dout         ),
        .empty  (f_empty        )
    );


    // DUT
    wire                        id_pair_read;
    wire [2*VEC_ID_WIDTH-1:0]   id_pair_out;
    wire                        id_pair_ready;

    assign id_pair_read = id_pair_ready;

    tanimoto_top
    #(
        .BUS_WIDTH      (BUS_WIDTH      ),
        .VECTOR_WIDTH   (VECTOR_WIDTH   ),
        .SUB_VECTOR_NO  (SUB_VECTOR_NO  ),
        .GRANULE_WIDTH  (GRANULE_WIDTH  ),
        .SHR_DEPTH      (SHR_DEPTH      ),
        .VEC_ID_WIDTH   (VEC_ID_WIDTH   )
    ) dut (
        .clk                    (clk            ),
        .rstn                   (~rst           ),
        .i_Vector               (f_dout         ),
        .i_Valid                (~f_empty       ),
        .i_BRAM_Addr            (threshold_addr ),
        .i_BRAM_Din             (threshold      ),
        .i_BRAM_En              (1'b1           ),
        .i_BRAM_WrEn            (wr_threshold   ),
        .i_IDPair_Read          (id_pair_read   ),
        .o_Read                 (f_read         ),
        .o_IDPair_Ready         (id_pair_ready  ),
        .o_IDPair_Out           (id_pair_out    )
    );

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
        #CLK_PERIOD;
        wr_threshold <= 1;
        for(integer i = 0; i < VECTOR_WIDTH; i = i + 1) begin
            threshold = threshold + 1;
            threshold_addr = threshold_addr + 1;
            #CLK_PERIOD;
        end
        wr_threshold <= 0;
    end

    // fill FIFOs
    integer fp_vec;
    integer scan;
    reg [BUS_WIDTH-1:0] vec;
    initial begin
        fp_vec = $fopen("/home/jozmoz01/Documents/fp_accel/tanimoto_rtl/test_vectors.dat", "r");
        if(fp_vec == 0) begin
            $display("ERROR: File containing test vectors was not found...");
            $finish;
        end
    end

    reg f_write_d;
    always @ (posedge clk)
    begin
        if(rst) begin
            f_write_d <= 0;
        end else begin
            f_write_d <= f_write;
        end
    end

    always @ (posedge clk)
    begin
        if(~rst & f_write) begin
            scan = $fscanf(fp_vec, "%h\n", vec);
            if(!$feof(fp_vec)) begin
                f_din <= vec;
            end else begin
                $fclose(fp_vec);
            end
        end
    end


    initial begin
        #100;
        rst <= 1'b0;
        #CLK_PERIOD;
        threshold = 650;
        #CLK_PERIOD;
        #500;
        f_write <= 1'b1;
        if($feof(fp_vec)) begin
            f_write <= 1'b0;
        end
        #CLK_PERIOD;
    end

    // write results to file
    integer fp_id;
    initial begin
        fp_id = $fopen("/home/jozmoz01/Documents/fp_accel/tanimoto_rtl/id_out.txt", "w");
        if(fp_id == 0) begin
            $display("ERROR: Logfile for ID pairs could not be opened...");
            $finish;
        end

        #10000;
        $fclose(fp_id);
    end

    always @ (posedge clk)
    begin
        if(!rst && id_pair_ready) begin
            $fdisplay(fp_id, "%h\n", id_pair_out);
        end
    end


endmodule

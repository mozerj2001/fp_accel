`ifndef BIT_CNTR_WRAPPER
`define BIT_CNTR_WRAPPER

`timescale 1ns / 1ps
`default_nettype none

`include "bit_cntr.v"


module bit_cntr_wrapper
    #(
        parameter VECTOR_WIDTH  = 920,
        parameter GRANULE_WIDTH = 6,
        parameter OUTPUT_WIDTH  = 16
    )
    (
        input wire                      clk,
        input wire                      rst,
        input wire [VECTOR_WIDTH-1:0]   i_Vector,
        input wire                      i_Valid,
        input wire                      i_LastWordOfVector,

        output wire [OUTPUT_WIDTH-1:0]  o_Sum,
        output wire                     o_SumValid,
        output wire                     o_SumNew        // o_Sum can be read
    );

    // number of clk cycles between vector entry and sum appearing on the
    // bit_cntr o_Sum output
    localparam DELAY = $rtoi($ceil($log10($itor(VECTOR_WIDTH)/($itor(GRANULE_WIDTH)*3.0))/$log10(3.0)));

    /////////////////////////////////////////////////////////////////////////////////////
    // BIT COUNTER 
    // --> count bits in the input vector
    wire [$clog2(VECTOR_WIDTH):0] w_NewSum;

    bit_cntr
    #(
        .VECTOR_WIDTH   (VECTOR_WIDTH   ), 
        .GRANULE_WIDTH  (GRANULE_WIDTH  )
    ) pipelined_counter (
        .clk            (clk            ),
        .rst            (rst            ),
        .i_Vector       (i_Vector       ),

        .o_Sum          (w_NewSum       ) 
    );

    /////////////////////////////////////////////////////////////////////////////////////
    // DELAY SIGNALS
    reg r_DelayValidFF      [DELAY-1:0];
    reg r_DelayLastWordFF   [DELAY-1:0];

    genvar ii;
    generate
        for(ii = 0; ii <= DELAY-1; ii = ii + 1) begin
            if(ii == 0) begin
                always @ (posedge clk) begin
                    if(rst) begin
                        r_DelayValidFF[ii]      <= 1'b0;
                        r_DelayLastWordFF[ii]   <= 1'b0;
                    end else begin
                        r_DelayValidFF[ii]      <= i_Valid;
                        r_DelayLastWordFF[ii]   <= i_LastWordOfVector;        
                    end
                end
            end
            else
            begin
                always @ (posedge clk) begin
                    if(rst) begin
                        r_DelayValidFF[ii]      <= 1'b0;
                        r_DelayLastWordFF[ii]   <= 1'b0;
                    end else begin
                        r_DelayValidFF[ii]      <= r_DelayValidFF[ii-1];
                        r_DelayLastWordFF[ii]   <= r_DelayLastWordFF[ii-1];        
                    end
                end
            end
        end
    endgenerate

    assign o_SumValid   = r_DelayValidFF    [DELAY-1];
    assign o_SumNew     = r_DelayLastWordFF [DELAY-1];


    /////////////////////////////////////////////////////////////////////////////////////
    // ACCUMULATOR
    reg [OUTPUT_WIDTH-1:0] r_Accumulator;

    always @ (posedge clk)
    begin
        if(rst) begin
            r_Accumulator <= 0;
        end
        else if(r_DelayLastWordFF[DELAY-1]) begin
            r_Accumulator <= w_NewSum;
        end
        else if(r_DelayValidFF[DELAY-1]) begin
            r_Accumulator <= r_Accumulator + w_NewSum;
        end
    end

    assign o_Sum = r_Accumulator;

endmodule

`endif
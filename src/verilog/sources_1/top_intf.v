
`ifndef TOP_INTF
`define TOP_INTF


`timescale 1ns / 1ps
`default_nettype none

module top_intf
    #(
        BUS_WIDTH       = 512                   ,
        VECTOR_WIDTH    = 920                   ,
        SHR_DEPTH       = 32                    ,
        //
        SUB_VECTOR_NO   = 2                     ,
        GRANULE_WIDTH   = 6                     ,
        VEC_ID_WIDTH    = 8                     ,
        //
        CNT_WIDTH       = $clog2(VECTOR_WIDTH)
    )(
        input wire                          ap_clk              ,
        input wire                          ap_rstn             ,
        // S_AXIS_DATA vector input stream
        input wire [BUS_WIDTH-1:0]          S_AXIS_DATA_tdata    ,
        input wire                          S_AXIS_DATA_tvalid   ,
        output wire                         S_AXIS_DATA_tready   ,
        // M_AXIS_ID_PAIR ID pair output stream
        output wire [2*VEC_ID_WIDTH-1:0]    M_AXIS_ID_PAIR_tdata ,
        output wire                         M_AXIS_ID_PAIR_tvalid,
        input wire                          M_AXIS_ID_PAIR_tready,
        // Comparator BRAM interface
        input wire                          BRAM_PORTA_clk_a    ,
        input wire                          BRAM_PORTA_rst_a    ,  
        input wire [CNT_WIDTH-1:0]          BRAM_PORTA_addr_a   ,
        input wire [CNT_WIDTH-1:0]          BRAM_PORTA_wrdata_a , 
        output wire [CNT_WIDTH-1:0]         BRAM_PORTA_rddata_a , 
        input wire                          BRAM_PORTA_en_a     ,  
        input wire                          BRAM_PORTA_we_a
    );

    // S_AXIS_DATA signals
    wire [BUS_WIDTH-1:0]    i_Vector;
    wire                    i_Valid ;
    wire                    o_Read  ;

    assign i_Vector             = S_AXIS_DATA_tdata  ;
    assign i_Valid              = S_AXIS_DATA_tvalid ;
    assign S_AXIS_DATA_tready    = o_Read            ;

    // M_AXIS_ID_PAIR signals
    wire [2*VEC_ID_WIDTH-1:0]   o_IDPair_Out    ;
    wire                        o_IDPair_Ready  ;
    wire                        i_IDPair_Read   ;

    assign M_AXIS_ID_PAIR_tdata  = o_IDPair_Out          ;
    assign M_AXIS_ID_PAIR_tvalid = o_IDPair_Ready        ;
    assign i_IDPair_Read        = M_AXIS_ID_PAIR_tready  ;

    // BRAM_PORTA signals
    wire                          i_BRAM_Clk    ;
    wire                          i_BRAM_Rst    ;
    wire [CNT_WIDTH-1:0]          i_BRAM_Addr   ;
    wire [CNT_WIDTH:0]            i_BRAM_Din    ;
    wire                          i_BRAM_En     ;
    wire                          i_BRAM_WrEn   ;

    assign i_BRAM_Clk           = BRAM_PORTA_clk_a      ;
    assign i_BRAM_Rst           = BRAM_PORTA_rst_a      ;
    assign i_BRAM_Addr          = BRAM_PORTA_addr_a     ;
    assign i_BRAM_Din           = BRAM_PORTA_wrdata_a   ;
    assign i_BRAM_En            = BRAM_PORTA_en_a       ;
    assign i_BRAM_WrEn          = BRAM_PORTA_we_a       ;
    assign BRAM_PORTA_rddata_a  = 0;

    tanimoto_top #(
        .BUS_WIDTH      (BUS_WIDTH          ),
        .VECTOR_WIDTH   (VECTOR_WIDTH       ),
        .SUB_VECTOR_NO  (SUB_VECTOR_NO      ),
        .GRANULE_WIDTH  (GRANULE_WIDTH      ),
        .SHR_DEPTH      (SHR_DEPTH          ),
        .VEC_ID_WIDTH   (VEC_ID_WIDTH       )
    ) u_tanimoto_top (
        .clk            (ap_clk         ),
        .rstn           (ap_rstn        ),
        .i_Vector       (i_Vector       ),
        .i_Valid        (i_Valid        ),
        .i_BRAM_Clk     (i_BRAM_Clk     ),
        .i_BRAM_Rst     (i_BRAM_Rst     ),  
        .i_BRAM_Addr    (i_BRAM_Addr    ),
        .i_BRAM_Din     (i_BRAM_Din     ), 
        .i_BRAM_En      (i_BRAM_En      ),  
        .i_BRAM_WrEn    (i_BRAM_WrEn    ),
        .i_IDPair_Read  (i_IDPair_Read  ),
        .o_Read         (o_Read         ),
        .o_IDPair_Ready (o_IDPair_Ready ),
        .o_IDPair_Out   (o_IDPair_Out   ) 
    );

endmodule

`endif // TOP_INTF




#ifndef HLS_DMA_H
#define HLS_DMA_H

#include <stdio.h>
#include <hls_stream.h>
#include "ap_axi_sdata.h"
#include "hls_dma.h"


#define BUS_WIDTH 128
#define BUS_WIDTH_BYTES 16
#define VEC_ID_WIDTH 8
#define REF_VEC_NO 8                            // how many ref_vecs can be pushed before the comparison vectors (SHR_DEPTH)
#define AXI_BURST_LENGTH 16

typedef ap_uint<BUS_WIDTH>         	bus_t;       // 512 bit wide data word
typedef ap_uint<VEC_ID_WIDTH*2> 	   id_pair_t;   // pair of output vector IDs
typedef ap_uint<1>                  bit_t;

// AXI Stream lib types for interfaces
typedef hls::axis<bus_t, 1, 0, 0>       axis_vec_t;
typedef hls::axis<id_pair_t, 1, 0, 0>   axis_id_pair_t;
typedef hls::stream<axis_vec_t>         axi_stream_vec_t;
typedef hls::stream<axis_id_pair_t>     axi_stream_id_pair_t;


void do_axi_burst_read( bus_t* axi_in,
                        bus_t  buf_out[AXI_BURST_LENGTH] );

void mm2stream( bus_t*             vec_in,
                axi_stream_vec_t&  vec_out,
				unsigned int       data_word_no,
                unsigned int       last
            );

void vec_intf(  bus_t*              ref_vec,
                bus_t*              cmp_vec,
                axi_stream_vec_t&   vec_out,
                unsigned int        ref_sub_vec_no,
                unsigned int        cmp_sub_vec_no
            );

void id_intf(   axi_stream_id_pair_t& id_in,
                id_pair_t*            id_out
            );

extern "C" void hls_dma(    bus_t*                  vec_ref,
                            bus_t*                  vec_cmp,
                            axi_stream_vec_t&       vec_out,
                            axi_stream_id_pair_t&   id_in,
                            id_pair_t*              id_out,
                            unsigned int            ref_sub_vec_no,
                            unsigned int            cmp_sub_vec_no
                        );

#endif

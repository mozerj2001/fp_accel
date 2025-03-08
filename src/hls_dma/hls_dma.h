#ifndef HLS_DMA_H
#define HLS_DMA_H

#include <stdio.h>
#include <hls_stream.h>
#include "ap_axi_sdata.h"
#include "hls_dma.h"


#define BUS_WIDTH 512
#define VEC_ID_WIDTH 8
#define REF_VEC_NO 8							// how many ref_vecs can be pushed before the comparison vectors (SHR_DEPTH)

typedef ap_uint<BUS_WIDTH> 		bus_t;			// 512 bit wide data word
typedef ap_uint<VEC_ID_WIDTH>	vec_no_t;		// number of CMP vectors, corresponds to VEC_ID_WIDTH and the corresponding handshake interface data width
typedef ap_uint<VEC_ID_WIDTH*2> id_pair_t;		// pair of output vector IDs

// AXI Stream lib types for interfaces
typedef hls::axis<bus_t, 0, 0, 0> 		axis_vec_t;
typedef hls::axis<id_pair_t, 0, 0, 0> 	axis_id_pair_t;
typedef hls::stream<axis_vec_t> 		axi_stream_vec_t;
typedef hls::stream<axis_id_pair_t> 	axi_stream_id_pair_t;



void vec_intf(  bus_t*              vec_ref,
                bus_t*              vec_cmp,
                axi_stream_vec_t& 	vec_out);

void id_intf(   axi_stream_id_pair_t& 	id_in,
                id_pair_t*              id_out);

extern "C" void hls_dma(  	bus_t*                  vec_ref,
							bus_t*                  vec_cmp,
							axi_stream_vec_t&     	vec_out,
							axi_stream_id_pair_t& 	id_in,
							id_pair_t* 				id_out,
							vec_no_t				cmp_vec_no_in,
							vec_no_t				cmp_vec_no_out);

#endif

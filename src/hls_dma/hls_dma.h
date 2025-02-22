#ifndef HLS_DMA_H
#define HLS_DMA_H

#include "ap_int.h"

#define BUS_WIDTH 512
#define VEC_ID_WIDTH 8
#define REF_VEC_NO 8		// how many ref_vecs can be pushed before cmp (SHR_DEPTH)
#define CMP_VEC_NO 92		// how many cmp_vecs will be pushed

typedef ap_uint<BUS_WIDTH> bus_t;
typedef ap_uint<VEC_ID_WIDTH*2> id_pair_t;


void vec_intf(bus_t* vec_ref, bus_t* vec_cmp, bus_t* vec_out);
void id_intf(id_pair_t* id_in, id_pair_t* id_out);
extern "C" void hls_dma(  	bus_t* vec_ref,
							bus_t* vec_cmp,
							bus_t* vec_out,
							id_pair_t* id_in,
							id_pair_t* id_out);

#endif

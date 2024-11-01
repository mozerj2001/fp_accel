#include <stdio.h>
#include "ap_axi_sdata.h"
#include "hls_dma.h"

// AXI ==> AXI Stream

/*
 * vec_ref: 	AXI source of reference vectors.
 * vec_cmp: 	AXI source of vectors to be compared against reference vectors.
 * REF_READ_NO:	Number of bus cycles carrying reference vectors. Corresponds to the SHR_DEPTH RTL parameter.
 * CMP_READ_NO:	Number of bus cycles carrying compare vectors.
 * vec_out: 	AXI-Stream sink of vectors, direct input of the tanimoto_top RTL module.
 */

void vec_intf(bus_t* vec_ref, bus_t* vec_cmp, bus_t* vec_out){
	bus_t tmp;

	ref_loop: for(unsigned int i = 0; i < REF_VEC_NO; i++){
		tmp = *vec_ref;
		*vec_out = tmp;
	}

	cmp_loop: for(unsigned int i = 0; i < CMP_VEC_NO; i++){
		tmp = *vec_cmp;
		*vec_out = tmp;
	}
}


// AXI-Stream ==> AXI

/*
 * id_in: ID pair output of tanimoto_top.
 * id_out: ID pairs forwarded to PS.
 *
 * NOTE: Only does one transaction, as the number of ID pair data that needs
 * to be read is unknown.
 */

void id_intf(id_out_t* id_in, id_out_t* id_out){

	id_out_t tmp;

	tmp = *id_in;
	*id_out = tmp;

}


// Interface

void hls_dma(bus_t* vec_ref, bus_t* vec_cmp, bus_t* vec_out, id_pair_t* id_in, id_pair_t* id_out){
#pragma HLS INTERFACE m_axi port=vec_ref bundle=gmem1
#pragma HLS INTERFACE m_axi port=vec_cmp bundle=gmem1
#pragma HLS INTERFACE m_axi port=vec_out bundle=gmem2
#pragma HLS INTERFACE axis port=id_in
#pragma HLS INTERFACE axis port=id_out

#pragma HLS dataflow

	vec_intf(vec_ref, vec_cmp, vec_out);
	id_intf(id_in, id_out);

}








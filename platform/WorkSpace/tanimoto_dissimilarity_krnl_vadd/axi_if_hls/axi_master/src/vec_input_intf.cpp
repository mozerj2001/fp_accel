#include <stdio.h>
#include "ap_axi_sdata.h"
#include "if.h"


/*
 * vec_ref: 	AXI-Lite source of reference vectors.
 * vec_cmp: 	AXI-Lite source of vectors to be compared against reference vectors.
 * REF_READ_NO:	Number of bus cycles carrying reference vectors.
 * CMP_READ_NO:	Number of bus cycles carrying compare vectors.
 * vec_out: 	AXI-Stream sink of vectors, direct input of the top_cnt RTL module.
 */

// AXI-Lite ==> AXI-Stream
void vec_input_intf(bus_t* vec_ref, bus_t* vec_cmp, bus_t* vec_out){
#pragma HLS INTERFACE mode=ap_ctrl_none port=return
#pragma HLS INTERFACE mode=s_axilite port=vec_ref
#pragma HLS INTERFACE mode=s_axilite port=vec_cmp
#pragma HLS INTERFACE mode=axis register_mode=both port=vec_out register

	bus_t tmp;

	// Copy reference vectors to vec_out.
	for(unsigned int i = 0; i < REF_READ_NO; i++){
		tmp = *vec_ref;
		*vec_out = tmp;
	}

	// Copy vectors to be compared against the reference vectors to vec_out.
	for(unsigned int i = 0; i < CMP_READ_NO; i++){
			tmp = *vec_cmp;
			*vec_out = tmp;
	}

}




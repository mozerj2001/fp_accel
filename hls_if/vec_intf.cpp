#include <stdio.h>
#include "ap_axi_sdata.h"
#include "if.h"


/*
 * vec_ref: 	AXI source of reference vectors.
 * vec_cmp: 	AXI source of vectors to be compared against reference vectors.
 * REF_READ_NO:	Number of bus cycles carrying reference vectors.
 * CMP_READ_NO:	Number of bus cycles carrying compare vectors.
 * vec_out: 	AXI-Stream sink of vectors, direct input of the top_cnt RTL module.
 */

// AXI ==> AXI-Stream
void vec_input_intf(bus_t* vec_ref, bus_t* vec_cmp, bus_t* vec_out){

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


/*
 * id_in: ID pair output of top_cnt.
 * id_out: ID pairs forwarded to PS.
 *
 * NOTE: Only does one transaction, as the number of ID pair data that needs
 * to be read is unknown.
 */

// AXI-Stream ==> AXI
void vec_output_intf(id_out_t* id_in, id_out_t* id_out){

	id_out_t tmp;

	tmp = *id_in;
	*id_out = tmp;

}

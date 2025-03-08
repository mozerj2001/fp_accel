#include <stdio.h>
#include <hls_stream.h>
#include "ap_axi_sdata.h"
//#include "ap_utils.h"
#include "hls_dma.h"

// AXI ==> AXI Stream

/*
 * vec_ref: 	AXI source of reference vectors.
 * vec_cmp: 	AXI source of vectors to be compared against reference vectors.
 * REF_READ_NO:	Number of bus cycles carrying reference vectors. Corresponds to the SHR_DEPTH RTL parameter.
 * CMP_READ_NO:	Number of bus cycles carrying compare vectors, passed through to the corresponding register in the RTL.
 * vec_out: 	AXI-Stream sink of vectors, direct input of the tanimoto_top RTL module.
 */

void vec_intf(	bus_t* 				vec_ref,
				bus_t* 				vec_cmp,
				axi_stream_vec_t& 	vec_out,
				vec_no_t			cmp_vec_no_in	)
{

	axis_vec_t tmp;
	int unsigned i, j;

	ref_loop: for(unsigned int i = 0; i < REF_VEC_NO; i++){
		tmp.data = *(vec_ref++);
		vec_out.write(tmp);
	}

	i = 0;
	while(1){
		cmp_loop: for(unsigned int j = 0; j < 256; j++){
			tmp.data = *(vec_cmp++);
			vec_out.write(tmp);

			i++;
			if(i == cmp_vec_no_in) break;
		}
		if(i == cmp_vec_no_in) break;
	}
}


// AXI-Stream ==> AXI

/*
 * id_in: ID pair output of tanimoto_top.
 * id_out: ID pairs forwarded to PS.
 *
 * NOTE: Only does one transaction, as the number of ID pair data that needs
 * to be read is unknown.
 * TODO: Add pipeline flushing, not all ID-pairs will make it out until done == 1.
 */

void id_intf(	axi_stream_id_pair_t& 	id_in,
				id_pair_t* 				id_out	)
{

    axis_id_pair_t tmp;

    id_loop: while(1){
        tmp = id_in.read();
		*(id_out++) = tmp.data;
		if(tmp.last) break;
	}

}


// Interface

void hls_dma(	bus_t* 					vec_ref,
				bus_t* 					vec_cmp,
				axi_stream_vec_t& 		vec_out,
				axi_stream_id_pair_t& 	id_in,
				id_pair_t* 				id_out,
				vec_no_t				cmp_vec_no_in,
				vec_no_t				cmp_vec_no_out	)
{
#pragma HLS INTERFACE mode=m_axi bundle=gmem1 max_read_burst_length=256 port=vec_ref
#pragma HLS INTERFACE mode=m_axi bundle=gmem1 max_read_burst_length=256 port=vec_cmp
#pragma HLS INTERFACE mode=axis register_mode=both port=vec_out register
#pragma HLS INTERFACE mode=axis register_mode=both port=id_in register
#pragma HLS INTERFACE mode=m_axi bundle=gmem2 port=id_out
#pragma HLS INTERFACE mode=ap_hs port=cmp_vec_no_in
#pragma HLS INTERFACE mode=ap_hs port=cmp_vec_no_out

	cmp_vec_no_out = cmp_vec_no_in;

#pragma HLS DATAFLOW
	vec_intf(vec_ref, vec_cmp, vec_out, cmp_vec_no_in);
	id_intf(id_in, id_out);

}








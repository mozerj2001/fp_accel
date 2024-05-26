#include <stdio.h>
#include "ap_axi_sdata.h"
#include "if.h"


/*
 * id_in: ID pair output of top_cnt.
 * id_out: ID pairs forwarded to PS.
 */

// AXI-Stream ==> AXI-Lite
void vec_output_intf(id_out_t* id_in, id_out_t* id_out){
#pragma HLS INTERFACE mode=ap_ctrl_none port=return
#pragma HLS INTERFACE mode=axis register_mode=both port=id_in register
#pragma HLS INTERFACE mode=s_axilite port=id_out

	id_t tmp;

	tmp = *id_in;
	*id_out = tmp;

}

#include <stdio.h>
#include "ap_axi_sdata.h"
#include "if.h"


/*
 * th_in:		AXI-Lite source of the current threshold value to be written to the IP.
 * th_out:		AP interface that is directly connected to the ports of the IP.
*/

// AXI-Lite ==> AP Intf
void threshold_intf(thresh_t* th_in, thresh_t* th_out){

	thresh_t tmp;

	tmp = *th_in;
	*th_out = tmp;

}




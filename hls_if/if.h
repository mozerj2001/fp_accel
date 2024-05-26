#ifndef IF_H
#define IF_H

#define VECTOR_WIDTH 		920
#define BUS_WIDTH 			512
#define VEC_ID_WIDTH		8
#define THRESHOLD_WIDTH		10

#define REF_READ_NO			32
#define CMP_READ_NO			128

#include <ap_int.h>

typedef ap_uint<BUS_WIDTH> 				bus_t;
typedef ap_uint<2*VEC_ID_WIDTH>			id_out_t;
typedef ap_uint<THRESHOLD_WIDTH>		thresh_t;

void threshold_intf(thresh_t* th_in, thresh_t* th_out);
void vec_input_intf(bus_t* vec_ref, bus_t* vec_cmp, bus_t* vec_out);
void vec_output_intf(id_out_t* id_in, id_out_t* id_out);
extern "C" void tan_intf(   thresh_t* th_in,
							thresh_t* th_out,
							bus_t* vec_ref,
							bus_t* vec_cmp,
							bus_t* vec_out,
							id_out_t* id_in,
							id_out_t* id_out);


#endif

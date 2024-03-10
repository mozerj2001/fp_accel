#define VECTOR_WIDTH 		920
#define BUS_WIDTH 			512
#define VEC_ID_WIDTH		8

#define REF_READ_NO			32
#define CMP_READ_NO			128

#include <ap_int.h>

typedef ap_uint<BUS_WIDTH> 				bus_t;
typedef ap_uint<2*VEC_ID_WIDTH>			id_t;

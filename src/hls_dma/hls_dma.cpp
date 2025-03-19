#include <stdio.h>
#include <hls_stream.h>
#include "ap_axi_sdata.h"
//#include "ap_utils.h"
#include "hls_dma.h"

// AXI ==> AXI Stream

/*
 * vec_ref:     AXI source of reference vectors.
 * vec_cmp:     AXI source of vectors to be compared against reference vectors.
 * REF_READ_NO:    Number of bus cycles carrying reference vectors. Corresponds to the SHR_DEPTH RTL parameter.
 * CMP_READ_NO:    Number of bus cycles carrying compare vectors, passed through to the corresponding register in the RTL.
 * vec_out:     AXI-Stream sink of vectors, direct input of the tanimoto_top RTL module.
 * --> buffering used to enable AXI bursts
 */

void vec_intf(    bus_t*                 vec_ref,
                bus_t*                 vec_cmp,
                axi_stream_vec_t&     vec_out,
                vec_no_t            cmp_vec_no_in    )
{

    axis_vec_t ref_buffer[REF_VEC_NO];
    axis_vec_t cmp_buffer[AXI_BURST_LENGTH];
    unsigned int remaining = cmp_vec_no_in;

    /*
     *    READ & WRITE REF VECTORS
     */

    ref_read_loop: for(unsigned int i = 0; i < REF_VEC_NO; i++){
        ref_buffer[i].data = *(vec_ref++);
    }

    ref_write_loop: for(unsigned int i = 0; i < REF_VEC_NO; i++){
        vec_out.write(ref_buffer[i]);
    }

    /*
     *    READ & WRITE CMP VECTORS
     */

    while(remaining >= AXI_BURST_LENGTH){
        
        cmp_read_loop: for(unsigned int i = 0; i < AXI_BURST_LENGTH; i++){
            cmp_buffer[i].data = *(vec_cmp++);
        }

        cmp_write_loop: for(unsigned int i = 0; i < AXI_BURST_LENGTH; i++){
            vec_out.write(cmp_buffer[i]);
        }

        remaining = remaining - AXI_BURST_LENGTH;
    }

    // Write remaining CMP vectors
    cmp_read_remaining_loop: for(unsigned int i = 0; i < remaining; i++){
        cmp_buffer[i].data = *(vec_cmp++);
    }

    cmp_write_remaining_loop: for(unsigned int i = 0; i < remaining; i++){
        vec_out.write(cmp_buffer[i]);
    }

    // RETURN: all vectors were pushed to the accelerator.

}


// AXI-Stream ==> AXI

/*
 * id_in: ID pair output of tanimoto_top.
 * id_out: ID pairs forwarded to PS.
 *
 * NOTE: Only does one transaction, as the number of ID pair data that needs
 * to be read is unknown.
 */

void id_intf(   axi_stream_id_pair_t&  id_in,
                id_pair_t*             id_out    )
{

    axis_id_pair_t tmp;

    id_loop: while(1){
        tmp = id_in.read();
        *(id_out++) = tmp.data;
        if(tmp.last) break;
    }

}

// Scalar AXI ==> AXI-Stream

/*
 * cmp_vec_no_in:     Number of compare (B) vectors in the next batch, written by the PS.
 * cmp_vec_no_out:     AXI-Stream port for valid-ready handshake IF in the accelerator.
 * NOTE: ap_hs could not be used, as it is not supported when running synthesis for Vitis kernels.
 */
void vec_no_intf(   vec_no_t                 cmp_vec_no_in,
                    axi_stream_vec_no_t&     cmp_vec_no_out    )
{
    axis_vec_no_t tmp;

    tmp.data = cmp_vec_no_in;
    cmp_vec_no_out.write(tmp);
}

// Interface

void hls_dma(   bus_t*                  vec_ref,
                bus_t*                  vec_cmp,
                axi_stream_vec_t&       vec_out,
                axi_stream_id_pair_t&   id_in,
                id_pair_t*              id_out,
                vec_no_t                cmp_vec_no_in,
                axi_stream_vec_no_t&    cmp_vec_no_out    )
{
#pragma HLS INTERFACE m_axi bundle=gmem1 max_read_burst_length=AXI_BURST_LENGTH port=vec_ref
#pragma HLS INTERFACE m_axi bundle=gmem1 max_read_burst_length=AXI_BURST_LENGTH port=vec_cmp
#pragma HLS INTERFACE axis register_mode=both port=vec_out register
#pragma HLS INTERFACE axis register_mode=both port=id_in register
#pragma HLS INTERFACE m_axi bundle=gmem2 port=id_out
#pragma HLS INTERFACE axis register_mode=both port=cmp_vec_no_out register

#pragma HLS DATAFLOW

    vec_no_intf(cmp_vec_no_in, cmp_vec_no_out);
    vec_intf(vec_ref, vec_cmp, vec_out, cmp_vec_no_in);
    id_intf(id_in, id_out);

}








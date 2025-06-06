#include <stdio.h>
#include <hls_stream.h>
#include "ap_axi_sdata.h"
//#include "ap_utils.h"
#include "hls_dma.h"

// AXI Burst Read Function

/*
 * axi_in:  AXI bus "pointer"
 * buf_out: Internal BRAM buffer to read into.
*/
void do_axi_burst_read(bus_t* axi_in, bus_t buf_out[AXI_BURST_LENGTH])
{
    for(unsigned int i = 0; i < AXI_BURST_LENGTH; i++){
        buf_out[i] = *(axi_in++);
    }
}

// AXI ==> AXI Stream

/*
 * vec_in:      AXI vector source, one word is 1 sub-vector sized (e. g. 512 bits)
 * vec_out:     AXI-Stream sink of vectors, direct input of the tanimoto_top RTL module.
 * sub_vec_no:  Number of data words to read and push.
 * --> constant size buffering used to promote the usage of AXI bursts wherever possible
 */

void mm2stream( bus_t*                vec_in,
                axi_stream_vec_t&     vec_out,
                unsigned int          data_word_no,
                unsigned int          last    )
{
	bus_t           data_buffer[AXI_BURST_LENGTH];
    axis_vec_t      tmp;
    unsigned int    remaining = data_word_no;

    while (remaining > AXI_BURST_LENGTH)
    {
        // Read into buffer
        do_axi_burst_read(vec_in, data_buffer);

        // Write to sink
        for(unsigned int i = 0; i < AXI_BURST_LENGTH; i++){
        	tmp.data = data_buffer[i];
        	tmp.last = 0;
        	vec_out.write(tmp);
        }

        remaining -= AXI_BURST_LENGTH;
    }

    for(unsigned int i = 0; i < remaining; i++){
        data_buffer[i] = *(vec_in++);
    }

    for(unsigned int i = 0; i < remaining-1; i++){
    	tmp.data = data_buffer[i];
    	tmp.last = 0;
    	vec_out.write(tmp);
    }
    
    tmp.data = data_buffer[remaining-1];
    if(last) tmp.last = 1;
    vec_out.write(tmp);

    // All vectors were pushed, return
}

/*
 * ref_vec:         AXI vector source for reference vectors.
 * cmp_vec:         AXI vector source for compare vectors.
 * ref_sub_vec_no:  Number of data words that are part of reference vectors.
 * cmp_sub_vec_no:  Number of data words that are part of compare vectors.
 * --> constant size buffering used to promote the usage of AXI bursts wherever possible
 */

void vec_intf(  bus_t*              ref_vec,
                bus_t*              cmp_vec,
                axi_stream_vec_t&   vec_out,
                unsigned int        ref_sub_vec_no,
                unsigned int        cmp_sub_vec_no
            )
{
    mm2stream(ref_vec, vec_out, ref_sub_vec_no, 0);
    mm2stream(cmp_vec, vec_out, cmp_sub_vec_no, 1);
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

// Interface

void hls_dma(   bus_t*                  vec_ref,
                bus_t*                  vec_cmp,
                axi_stream_vec_t&       vec_out,
                axi_stream_id_pair_t&   id_in,
                id_pair_t*              id_out,
                unsigned int            ref_sub_vec_no,
                unsigned int            cmp_sub_vec_no  )
{
#pragma HLS INTERFACE m_axi bundle=gmem1 max_read_burst_length=AXI_BURST_LENGTH port=vec_ref
#pragma HLS INTERFACE m_axi bundle=gmem1 max_read_burst_length=AXI_BURST_LENGTH port=vec_cmp
#pragma HLS INTERFACE axis register_mode=both port=vec_out register
#pragma HLS INTERFACE axis register_mode=both port=id_in register
#pragma HLS INTERFACE m_axi bundle=gmem2 port=id_out

#pragma HLS DATAFLOW

    vec_intf(vec_ref, vec_cmp, vec_out, ref_sub_vec_no, cmp_sub_vec_no);
    id_intf(id_in, id_out);

}








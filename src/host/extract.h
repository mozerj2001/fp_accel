#ifndef EXTRACT_H
#define EXTRACT_H

#include <stdlib.h>

int readVectorsFromFile(
    uint8_t* ptr_ref,
    uint8_t* ptr_cmp,
    const char* filename
);

size_t  readIDsFromFile(
    uint32_t** buf_in,
    const char* filename
);

void extractExpectedIDs(
    unsigned int _no_exp_ids,
    uint32_t*    _raw_id_exp,
    uint32_t**   ref_id_exp_,
    uint32_t**   cmp_id_exp_
);

unsigned int countOutputIDs(
    uint8_t* _id_buf
);

void extractResults(
    unsigned int _no_result_ids,
    uint8_t*     _result_buffer,
    uint32_t**   ref_id_result_,
    uint32_t**   cmp_id_result_
);

void dumpIDs(
    unsigned int _exp_id_num,
    uint32_t* _ref_id_exp,
    uint32_t* _cmp_id_exp,
    unsigned int _result_id_num,
    uint32_t* _ref_id_result,
    uint32_t* _cmp_id_result
);

#endif // EXTRACT_H
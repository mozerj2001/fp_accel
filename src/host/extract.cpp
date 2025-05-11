#include <fstream>
#include <iostream>
#include <bitset>
#include <stdlib.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <unistd.h>
#include "host.h"
#include "globals.h"
#include <CL/cl2.hpp>

/*
 * Function: readVectorsFromFile
 * ptr_ref_ - pre-allocated output array to contain reference vectors
 * ptr_cmp_ - pre-allocated output array to contain compare vectors
 * _filename - fully binary file to read vectors from
 * 
 * Description:
 * - Open binary file, read contents into _output arrays already existing in memory._
 * - Required globals: REF_VEC_NO, CMP_VEC_NO
 */
int readVectorsFromFile(uint8_t *ptr_ref_, uint8_t *ptr_cmp_, const char *_filename)
{
    FILE *fp = fopen(_filename, "rb");
    if (fp == NULL) {
        perror("[ERROR][FILE_OPS] Error opening vectors file");
        return 1;
    }

    size_t refBytes = REF_VEC_NO * 115;
    size_t cmpBytes = CMP_VEC_NO * 115;

    /* Read reference vectors (refBytes total) */
    size_t bytesRead = fread(ptr_ref_, sizeof(uint8_t), refBytes, fp);
    if (bytesRead != refBytes) {
        perror("[ERROR][FILE_OPS] Error reading reference vectors");
        fclose(fp);
        return 1;
    }

    /* Read comparison vectors (cmpBytes total) */
    bytesRead = fread(ptr_cmp_, sizeof(uint8_t), cmpBytes, fp);
    if (bytesRead != cmpBytes) {
        perror("[ERROR][FILE_OPS] Error reading comparison vectors");
        fclose(fp);
        return 1;
    }

    fclose(fp);
    return 0;
}

/*
 * Function: readIDsFromFile
 * buf_out_ - data output pointer, _memory will be allocated by the function_
 * _filename - filename
 */
size_t readIDsFromFile(uint32_t** buf_out_, const char* _filename)
{
    int bytes;
    int read;
    uint32_t *buf_in;

    std::cout << "[INFO] Read pre-calculated IDs from results file." << std::endl;

    FILE *fp = fopen(_filename, "rb");
    if (fp == NULL) {
        perror("[ERROR][FILE_OPS] Error opening results file");
        return 1;
    }

    if (fseek(fp, 0, SEEK_END) != 0) {
        perror("[ERROR][FILE_OPS] Error seeking results file!");
        fclose(fp);
        return -1;
    }

    bytes = ftell(fp);
    if (bytes < 0) {
        perror("[ERROR][FILE_OPS] Error telling pointer position of results file!");
        fclose(fp);
        return -1;
    }

    if ((bytes % sizeof(uint32_t)) != 0) {
        perror("[ERROR][FILE_OPS] Unexpected number of bytes in results file!");
        fclose(fp);
        return -1;
    }

    rewind(fp);

    buf_in = (uint32_t*) malloc(bytes);
    read = fread(buf_in, 1, bytes, fp);
    if (read != bytes) {
        perror("[ERROR][FILE_OPS] Unexpected number of bytes read from reasults file!");
        fclose(fp);
        free(buf_in);
        return -1;
    }

    fclose(fp);
    *buf_out_ = buf_in;

    return (size_t) (bytes / sizeof(uint32_t));
}

/* 
 * Function: extractExpectedIDs
 * _no_exp_ids - total number of expected IDs
 * _raw_id_exp - input array containing all expected IDs as uint32_t, interleaved in pairs
 * ref_id_exp_ - output array containing uninterleaved ref IDs, _order preserved, mem alloc by func_
 * cmp_id_exp_ - output array containing uninterleaved cmp IDs, _order preserved, mem alloc by func_
 */

void extractExpectedIDs(
    unsigned int _no_exp_ids,
    uint32_t*    _raw_id_exp,
    uint32_t**   ref_id_exp_,
    uint32_t**   cmp_id_exp_
){

    std::cout << "[INFO] Uninterleaving expected ID array." << std::endl;

    uint32_t* ref_id_exp = (uint32_t*) malloc(_no_exp_ids/2 * sizeof(uint32_t));
    uint32_t* cmp_id_exp = (uint32_t*) malloc(_no_exp_ids/2 * sizeof(uint32_t));

    for(unsigned int i = 0; i < _no_exp_ids/2; i++){
        ref_id_exp[i] = _raw_id_exp[2*i];
        cmp_id_exp[i] = _raw_id_exp[2*i+1];
    }

    *ref_id_exp_ = ref_id_exp;
    *cmp_id_exp_ = cmp_id_exp;

}

/*
 * Function: countOutputIDs
 * _id_buf - input array containing an unknown number of ID-pairs, terminated by a 0 ID.
 */
unsigned int countOutputIDs(
    uint8_t* _id_buf
){

    bool current_id_is_zero = false;
    unsigned int cnt = 0;

    // Look for two consecutive zeroes
    while(!current_id_is_zero){
        current_id_is_zero = true;

        for(unsigned int i = 0; i < ID_SIZE; i++){
            if(_id_buf[ID_SIZE*cnt+i] != 0){
                current_id_is_zero = false;
            }
        }

        cnt++;
    }

    return cnt-1;
}

/*
 * Function: extractResults
 * _no_result_ids - Number of IDs in the input _result_buffer.
 * _result_buffer - Buffer containing ID pairs in order, interleaved.
 * ref_id_result_ - Output array for uninterleaved reference IDs, in order.
 * cmp_id_result_ - Output array for uninterleaved compare IDs, in order.
 * _Memory for output arrays allocated by the function._
 * 
 * Description:
 * Convert ID_SIZE byte wide vector IDs to uint32_t, store them in intermediate
 * array. Then uninterleave the intermediate array into the output arrays.
 */
void extractResults(
    unsigned int _no_result_ids,
    uint8_t*     _result_buffer,
    uint32_t**   ref_id_result_,
    uint32_t**   cmp_id_result_
){
    uint32_t tmp;
    uint32_t tmp_interleaved_buf[_no_result_ids];
    uint32_t* ref_id_result = (uint32_t*) malloc(_no_result_ids/2 * sizeof(uint32_t));
    uint32_t* cmp_id_result = (uint32_t*) malloc(_no_result_ids/2 * sizeof(uint32_t));

    for(unsigned int id = 0; id < _no_result_ids; id++){
        tmp = 0;

        for(unsigned int j = 0; j < ID_SIZE; j++){
            tmp += (uint32_t) _result_buffer[id*ID_SIZE+j];
            tmp = tmp << (ID_SIZE-j-1)*8;
        }

        tmp_interleaved_buf[id] = tmp;
    }

    for(unsigned int i = 0; i < _no_result_ids/2; i++){
        // interleaved in the other direction due to ID_out endianness
        ref_id_result[i] = tmp_interleaved_buf[2*i+1];
        cmp_id_result[i] = tmp_interleaved_buf[2*i];
    }

    *ref_id_result_ = ref_id_result;
    *cmp_id_result_ = cmp_id_result;

}


/*
 * Function: dumpIDs
 * Dump expected and actual results to human readable file.
 * _exp_id_num: Number of expected IDs.
 * _ref_id_exp: Input array for expected reference IDs.
 * _cmp_id_exp: Input array for expected compare IDs.
 * _result_id_num: Number of IDs written by the kernel.
 * _ref_id_result: Input array for reference IDs written by the kernel.
 * _cmp_id_result: Input array for compare IDs written by the kernel.
 */

void dumpIDs(
    unsigned int _exp_id_num,
    uint32_t* _ref_id_exp,
    uint32_t* _cmp_id_exp,
    unsigned int _result_id_num,
    uint32_t* _ref_id_result,
    uint32_t* _cmp_id_result
){
    FILE* fp = fopen("id_dump.txt", "w");

    if (!fp) {
        perror("[ERROR][FILE_OPS] Failed to open ID dump TXT file!");
        return;
    }

    fprintf(fp, "EXPECTED ID PAIRS (%d) ################################\n", _exp_id_num/2);
    for(unsigned int i = 0; i < _exp_id_num/2; i++){
        fprintf(fp, "%08x\t%08x\n", _ref_id_exp[i], _cmp_id_exp[i]);
    }

    fprintf(fp, "ACTUAL ID PAIRS (%d) ################################\n", _result_id_num/2);
    for(unsigned int i = 0; i < _result_id_num/2; i++){
        fprintf(fp, "%08x\t%08x\n", _ref_id_result[i], _cmp_id_result[i]);
    }

    fclose(fp);

}
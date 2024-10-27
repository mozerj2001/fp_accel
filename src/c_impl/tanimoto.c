#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <math.h>
#include <time.h>
#include "tanimoto.h"


/////////////////////////////////////////////////////////////////////////////////////////
void str_to_hex(char* str, uint_fast32_t* hex){

    unsigned int strLen = strlen(str);
    int idx;
    unsigned int currentInt = 0;            // integer value of each 8 neighbouring characters
    uint_fast32_t currentCharVal;
    char currentChar;
    unsigned int i, j;

    if(VECTOR_WIDTH/4 > strLen) { printf("ERROR: Input string too short!\n"); exit(1); }

    for(i = 0; i < WORD_NO; i++){       // Iterate through 32-bit words
        hex[i] = 0;
        for(j = 0; j < 8; j++){         // Iterate through 
            idx = strLen-(i*8+j)-1;

            if(idx < 0){                // Out of bounds
                currentChar = '0';
            } else {
                currentChar = str[idx];
            }

            if(currentChar <= '9')  { currentCharVal = (uint_fast32_t) (currentChar-'0'); }
            else                    { currentCharVal = (uint_fast32_t) (currentChar-'7'); }
            hex[i] += currentCharVal * pow(16.0, (double) j);
        }
    }

}


/////////////////////////////////////////////////////////////////////////////////////////
void hex_to_str(uint_fast32_t* hex, char** str){
    unsigned int strLen = VECTOR_WIDTH/4;
    int idx;
    char currentChar;
    int i, j;
    uint_fast32_t tmp;

    *str = (char*) malloc(strLen+1);

    for(i = 0; i < WORD_NO; i++){           // Iterate 32 bit words
        tmp = hex[i];
        for(j = 0; j < 8; j++){             // Iterate 4 bit digits
            switch(tmp & 0x0000000F){
                case 0: currentChar = '0'; break;
                case 1: currentChar = '1'; break;
                case 2: currentChar = '2'; break;
                case 3: currentChar = '3'; break;
                case 4: currentChar = '4'; break;
                case 5: currentChar = '5'; break;
                case 6: currentChar = '6'; break;
                case 7: currentChar = '7'; break;
                case 8: currentChar = '8'; break;
                case 9: currentChar = '9'; break;
                case 10: currentChar = 'A'; break;
                case 11: currentChar = 'B'; break;
                case 12: currentChar = 'C'; break;
                case 13: currentChar = 'D'; break;
                case 14: currentChar = 'E'; break;
                case 15: currentChar = 'F';
            }

            tmp = (tmp >> 4);
            idx = strLen - (i*8+j) - 1;

            if(idx >= 0){
                *(*str + idx) = currentChar;
            } else {
                return;
            }
        }
    }

    str[i*8] = '\0';
}


/////////////////////////////////////////////////////////////////////////////////////////
unsigned int read_vectors(char* fname, FINGERPRINT** fp_vector_array){

    long int fileSize;                  // no of bytes in vector database
    long int vectorNo;                  // no of lines in vector database
    char currentLine[WORD_NO*8+1];      // line currently read from file
    unsigned int i = 0;
    FILE* fp = fopen(fname, "r");
    if(fp == NULL) { exit(-1); }

    // set values necessary for dynamic allocations
    fseek(fp, 0, SEEK_END);
    fileSize = ftell(fp);
    vectorNo = fileSize/(WORD_NO*4+1) + 1;
    rewind(fp);

    printf("Input file is %ld bytes long...\n", fileSize);
    printf("Allocating memory for %ld vectors...\n", vectorNo);

    *fp_vector_array = (FINGERPRINT*) malloc(sizeof(FINGERPRINT)*vectorNo);

    while(fgets(currentLine, WORD_NO*8+1, fp)){
        str_to_hex(currentLine, (*fp_vector_array)[i].vector);
        if(i == vectorNo){ break; } else { i++; }
    }

    return i;
}


/////////////////////////////////////////////////////////////////////////////////////////
void print_fingerprint(FINGERPRINT f_print){
    unsigned int i;
    char* str;

    hex_to_str(f_print.vector, &str);

    printf("%s\n", str);
    printf("WEIGHT: %d\n", f_print.weight);
    free(str);
}


/////////////////////////////////////////////////////////////////////////////////////////
unsigned int  CNT1(uint_fast32_t n){
    unsigned int cnt = 0;

    while (n) {
        n &= (n - 1);
        cnt++;
    }

    return cnt;
}


/////////////////////////////////////////////////////////////////////////////////////////
void set_fp_weight(FINGERPRINT* fp){
    unsigned int i;
    fp -> weight = 0;
    for(i = 0; i < WORD_NO; i++){
        fp -> weight += CNT1(fp -> vector[i]);
    }
}


/////////////////////////////////////////////////////////////////////////////////////////
FINGERPRINT get_bitwise_and(FINGERPRINT A, FINGERPRINT B){
    unsigned int i;
    FINGERPRINT C;

    for(i = 0; i < WORD_NO; i++){
        C.vector[i] = A.vector[i] & B.vector[i];
    }

    return C;
}


/////////////////////////////////////////////////////////////////////////////////////////
FINGERPRINT get_rand_fp(){
    unsigned int i;
    FINGERPRINT fp;

    struct timespec ts;
    timespec_get(&ts, TIME_UTC);
    srand(ts.tv_nsec);

    for(i = 0; i < WORD_NO; i++){
        fp.vector[i] = (uint_fast32_t) rand();
    }
    set_fp_weight(&fp);
    
    return fp;
}


/////////////////////////////////////////////////////////////////////////////////////////
void gen_test_set(FINGERPRINT* A, unsigned int n_A, FINGERPRINT* B, unsigned int n_B, char* fname_ref, char* fname_cmp){
    char* str;
    unsigned int i;
    FILE* f_ptr;

    f_ptr = fopen(fname_ref, "w");

    for(i = 0; i < n_A; i++){
        A[i] = get_rand_fp();
        hex_to_str(A[i].vector, &str);
        fprintf(f_ptr, "%s\n", str);
        free(str);
    }

    fclose(f_ptr);
    f_ptr = fopen(fname_cmp, "w");

    for(i = 0; i < n_B; i++){
        B[i] = get_rand_fp();
        hex_to_str(B[i].vector, &str);
        fprintf(f_ptr, "%s\n", str);
        free(str);
    }

    fclose(f_ptr);
}


/////////////////////////////////////////////////////////////////////////////////////////
// unsigned int calc_tanimoto(FINGERPRINT* A, FINGERPRINT* B, unsigned int thresh, unsigned int* out_arr[][]){
//     unsigned int i, j;
//     unsigned int numA = sizeof(A)/sizeof(FINGERPRINT);
//     unsigned int numB = sizeof(B)/sizeof(FINGERPRINT);
//     unsigned int cntPair = 0;
//     double tnDissim;
//     FINGERPRINT C;
// 
//     for(i = 0; i < numA; i++){      // iterate through reference vectors
//         for(j = 0; j < numB; j++){  // iterate through compare vectors
//             C = get_bitwise_and(A[i], B[j]);
//             set_fp_weight(&C);
// 
//             tnDissim = (A[i].weight + B[j].weight) / C.weight;
//             if(tnDissim <= thresh){
//                 (*out_arr)[cntPair][0] = i;
//                 (*out_arr)[cntPair][1] = j;
//                 cntPair++;
//             }
//         }
//     }
// 
//     return cntPair;
// }


/////////////////////////////////////////////////////////////////////////////////////////
unsigned int calc_tanimoto_verif(FINGERPRINT* A, FINGERPRINT* B, unsigned int* thresh, unsigned int*** out_arr){
    unsigned int i, j;
    unsigned int numA = sizeof(A)/sizeof(FINGERPRINT);
    unsigned int numB = sizeof(B)/sizeof(FINGERPRINT);
    unsigned int cntPair = 0;
    unsigned int tnDissimVerif;
    FINGERPRINT C;

    for(i = 0; i < numA; i++){      // iterate through reference vectors
        for(j = 0; j < numB; j++){  // iterate through compare vectors
            C = get_bitwise_and(A[i], B[j]);
            set_fp_weight(&C);

            tnDissimVerif = A[i].weight + B[j].weight;
            if(tnDissimVerif <= thresh[C.weight]){
                (*out_arr)[cntPair][0] = i;
                (*out_arr)[cntPair][1] = j;
                cntPair++;
            }
        }
    }

    return cntPair;
}
























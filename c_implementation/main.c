#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <math.h>
#include "tanimoto.h"

int main(void){

    unsigned int i, j;
    FINGERPRINT A[REF_VEC_NO];
    FINGERPRINT B[CMP_VEC_NO];

    gen_test_set(A, REF_VEC_NO, B, CMP_VEC_NO, "ref_vec.txt", "cmp_vec.txt");

    return 0;
}
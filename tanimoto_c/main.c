#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <math.h>
#include "tanimoto.h"

int main(void){

    unsigned int i, j;
    unsigned int pairCnt;
    unsigned int idPairArr[REF_VEC_NO*CMP_VEC_NO][2];
    FINGERPRINT A[REF_VEC_NO];
    FINGERPRINT B[CMP_VEC_NO];

    gen_test_set(A, REF_VEC_NO, B, CMP_VEC_NO, "ref_vec.txt", "cmp_vec.txt");

    // pairCnt = calc_tanimoto(A, B, 300, &idPairArr);

    // for(i = 0; i < pairCnt; i++){
    //     printf("A: %d\tB: %d\n", idPairArr[i][0], idPairArr[i][1]);
    // }

    return 0;
}

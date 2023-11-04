#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <math.h>
#include "tanimoto.h"

int main(void){

    unsigned int i, j;
    FINGERPRINT* vec_arr;
    FINGERPRINT tmp;
    char* str;

    printf("WORD_NO = %d\n", WORD_NO);

    read_vectors("test_ref.txt", &vec_arr);

    for(i = 0; i < 4; i++){
        set_fp_weight(&vec_arr[i]);
    }

    for(i = 0; i < 4; i++){
        print_fingerprint(vec_arr[i]);
    }

    tmp = get_rand_fp();
    print_fingerprint(tmp);

    free(vec_arr);

    return 0;
}
#ifndef TANIMOTO_H
#define TANIMOTO_H

#define VECTOR_WIDTH 128
#define WORD_NO VECTOR_WIDTH/32
#define REF_VEC_NO 32
#define CMP_VEC_NO 128


// Binary vector structure, implementing a pharmacophore fingerprint.
typedef struct{
    uint32_t weight;
    uint_fast32_t vector[WORD_NO];
} FINGERPRINT;


// PURPOSE: Convert input string, which codes hexadecimal
//  values as characters to an array of uint_fast32_t words.
// INPUT:
//  str: String coding hexadecimal vector in ASCII. Length
//      must be divisible by 8. Letters "ABCDEF" must be
//      upper-case. MSB first.
// OUTPUT:
//  hex: Output word array. uint32_t, words with higher index
//      code numbers with higher index.
void str_to_hex(char* str, uint_fast32_t* hex);


// PURPOSE: Convert input integer to string coding a hexa-
//  decimal representation.
// INPUT:
//  n: Integer array, the hex representation of which will be written
//      to str. Bits of numbers with a higher index in the array
//      are higher order bits of the hexadecimal string representation.
// OUTPUT:
//  str: String output, hexadecimal coding, MSB first.
void hex_to_str(uint_fast32_t* hex, char** str);


// PURPOSE: Read vectors from a TXT file into an array of FINGERPRINTs.
//      First, vector number shall be determined by counting file lines,
//      then vectors will be red into the dynamically allocated
//      fp_vector array.
// INPUT:
//  fname: "file.txt" filename of file containing a single vector per line,
//      coded to hexadecimal, represented by ASII characters.
// OUTPUT:
//  fp_vector: Pointer to array into which new vectors will be
//      created.
//  Return: Number of vectors.
unsigned int read_vectors(char* fname, FINGERPRINT** fp_vector_array);


// PURPOSE: Print values of the fingerprint to STDOUT.
// INPUT:
//  f_print: FINGERPRINT struct, which will be printed word-by word.
void print_fingerprint(FINGERPRINT f_print);


// PURPOSE: Calculate the number of 1 bits in the input number.
// INPUT:
//  n: Number, on which weight calculation will be performed.
// OUTPUT:
//  Return: Number of 1s in n.
// SEE: Brian Kernighan's algorithm.
unsigned int CNT1(uint_fast32_t n);


// PURPOSE: Calculate binary weight (no of 1s) in a FINGERPRINT.
// INPUT:
//  fp: Fingerprint, which's Hamming weight will be calculated.
// OUTPUT:
//  Return: Binary weight of fp.
void set_fp_weight(FINGERPRINT* fp);


// PURPOSE: Create a vector that contains the bitwise and of two vectors.
// INPUT:
//  A, B: Fingerprints, which will be brought into a bit-wise and connection.
// OUTPUT:
//  Return: A & B
FINGERPRINT get_bitwise_and(FINGERPRINT A, FINGERPRINT B);


// PURPOSE: Generate a fully random fingerprint.
// INPUT:
// OUTPUT:
//  Return: Generated FINGERPRINT.
FINGERPRINT get_rand_fp();


// PURPOSE: Generate a set of reference vectors and a set of compare vectors.
//      The generated vectors are also saved to two .txt files.
// INPUT:
//  n_A: Number of reference fingerprints to be genereated.
//  n_B: Number of compare fingerprints to be genereated.
//  fname_ref: Filename, into which reference fingerprints will be stored.
//  fname_cmp: Filename, into which compare fingerprints will be stored.
// OUTPUT:
//  A: Pointer to the array, in which refrence fingerprints will be stored.
//  B: Pointer to the array, in which compare fingerprints will be stored.
void gen_test_set(FINGERPRINT* A, unsigned int n_A, FINGERPRINT* B, unsigned int n_B, char* fname_ref, char* fname_cmp);


// PURPOSE: Calculate Tanimoto dissimilarity between a set of reference
//      fingerprints and an other set of fingerprints. If the dissimilarity
//      of two vectors is under a certain threshold, the index of those
//      vectors will be saved and returned as a pair.
// INPUT:
//  A: Pointer to the array of reference fingerprints.
//  B: Pointer to the array of compare fingerprints.
//  thresh: Threshold value, under which pairs will be returned.
// OUTPUT:
//  out_arr: 2D array containing index-pairs, the corresponding vectors
//      of which satisfy the threshold criterium. Assumed to be "large enough"
//      for all found pairs to fit. (For execution speed's sake.)
//  Return: Number of returned index-pairs.
unsigned int calc_tanimoto(FINGERPRINT* A, FINGERPRINT* B, double thresh, unsigned int*** out_arr);


// PURPOSE: Calculate a Tanimoto dissimilarity-like metric analogous to the
//      way the hardware implementation calculates it. Compare it to a threshold
//      and return pairs that satisfy the criterium.
//      This function is for the verification of the hardware simulation.
// INPUT:
//  A: Pointer to the array of reference fingerprints.
//  B: Pointer to the array of compare fingerprints.
//  thresh: Array containing threshold values for each possible CNT1(A&B) value.
// OUTPUT:
//  out_arr: 2D array containing index-pairs, the corresponding vectors
//      of which satisfy the threshold criterium. Assumed to be "large enough"
//      for all found pairs to fit. (For execution speed's sake.)
//  Return: Number of returned index-pairs.
unsigned int calc_tanimoto_verif(FINGERPRINT* A, FINGERPRINT* B, unsigned int* thresh, unsigned int*** out_arr);


#endif
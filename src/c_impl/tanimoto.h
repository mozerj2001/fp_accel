#ifndef TANIMOTO_H
#define TANIMOTO_H

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <time.h>
#include <getopt.h>
#include <stdbool.h>

#define REF_VECTOR_NO   8
#define CMP_VECTOR_NO   24
#define THRESHOLD       0.66

typedef struct {
    uint32_t id;                  /* ID of the vector */
    uint32_t weight;              /* Binary weight (number of set bits, etc.) */
    uint8_t  data[115];           /* The 920-bit wide vector data */
} BinaryVector;

extern BinaryVector referenceVectors[REF_VECTOR_NO];
extern BinaryVector comparisonVectors[CMP_VECTOR_NO];
extern BinaryVector intermediaryVectors[REF_VECTOR_NO*CMP_VECTOR_NO];

typedef struct {
    BinaryVector* A;
    BinaryVector* B;
    BinaryVector* C;
    double tanimotoCoefficient;         /* Calculated Tanimoto similarity coefficient */
} TanimotoResult;

extern TanimotoResult tanimotoResults[REF_VECTOR_NO*CMP_VECTOR_NO];

/* Fill vector data with randomly generated values */
void initVectors(bool generate);

/* Write ref and cmp vectors to binary file */
int  writeVectorsToFile(const char *filename);

/* Write the results of the calculation to binary file */
int  writeIDsToFile(const char *filename, double threshold);

/* Create C = A & B vectors */
void createIntermediaryVectors(void);

/* Calculate binary weight of the input vector */
void calculateBinaryWeight(BinaryVector *vec);

/* Calculate the Tanimoto coefficient using the weights of the input vectors */
double computeTanimotoSimilarity(const BinaryVector *ref,
                                 const BinaryVector *cmp,
                                 const BinaryVector *inter);

/* Tanimoto coeff for all global vectors */
void computeAllTanimotoSimilarities(void);

/* Print result struct to console */
void printResult(const TanimotoResult result, double threshold);

/* Export results to TXT file */
void printAllResultsToTxtFile(const char *filename);

#endif // TANIMOTO_H
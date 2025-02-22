#ifndef TANIMOTO_H
#define TANIMOTO_H

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <time.h>

#define REF_VECTOR_NO   8
#define CMP_VECTOR_NO   92
#define THRESHOLD       0.31

typedef struct {
    uint32_t id;                  /* ID of the vector */
    uint32_t weight;              /* Binary weight (number of set bits, etc.) */
    uint8_t  data[115];           /* The 920-bit wide vector data */
} BinaryVector;

extern BinaryVector referenceVectors[REF_VECTOR_NO];
extern BinaryVector comparisonVectors[CMP_VECTOR_NO];
extern BinaryVector intermediaryVectors[REF_VECTOR_NO*CMP_VECTOR_NO];

typedef struct {
    uint32_t referenceVectorID;         /* ID of the reference vector this result belongs to */
    uint32_t comparisonVectorID;        /* ID of the comparison vector this result belongs to */
    double tanimotoCoefficient;         /* Calculated Tanimoto similarity coefficient */
} TanimotoResult;

extern TanimotoResult tanimotoResults[REF_VECTOR_NO*CMP_VECTOR_NO];

void initVectors(void);                                         /* Fill vector data with randomly generated values */
int  writeVectorsToFile(const char *filename);                  /* Write ref and cmp vectors to binary file */
void createIntermediaryVectors(void);                           /* Create C = A & B vectors */
void calculateBinaryWeight(BinaryVector *vec);                  /* Calculate binary weight of the input vector */
double computeTanimotoSimilarity(const BinaryVector *ref,
                                 const BinaryVector *cmp,
                                 const BinaryVector *inter);    /* Calculate the Tanimoto coefficient using the weights of the input vectors */
void computeAllTanimotoSimilarities(void);                      /* Tanimoto coeff for all global vectors */
void printResult(const TanimotoResult result, double threshold);/* Print result struct to console */
void printAllResultsToTxtFile(const char *filename);            /* Export results to TXT file */

#endif // TANIMOTO_H
#include "tanimoto.h"

int main(void)
{
    // Create random vectors
    initVectors();

    // Export random vectors to binary file, to be read by the accelerator OCL kernel
    if (writeVectorsToFile("vectors.bin") != 0) {
        fprintf(stderr, "Error writing vectors to file.\n");
        return 1;
    }

    // Calculate C = A & B vectors
    createIntermediaryVectors();

    // Calculate CNT(1) for each vector
    for (int i = 0; i < REF_VECTOR_NO; i++) {
        calculateBinaryWeight(&referenceVectors[i]);
    }
    for (int i = 0; i < CMP_VECTOR_NO; i++) {
        calculateBinaryWeight(&comparisonVectors[i]);
    }
    for (int i = 0; i < REF_VECTOR_NO * CMP_VECTOR_NO; i++) {
        calculateBinaryWeight(&intermediaryVectors[i]);
    }

    // Calculate all Tanimoto similarity coefficients for each ref-cmp pair,
    // save results in the tanimotoResults[] array
    computeAllTanimotoSimilarities();

    // Take a look at some of the results locally
    for(int i = 0; i < REF_VECTOR_NO * CMP_VECTOR_NO; i++) {
        printResult(tanimotoResults[i], THRESHOLD);
    }

    printAllResultsToTxtFile("results.txt");

    return 0;
}
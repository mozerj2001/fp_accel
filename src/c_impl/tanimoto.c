#include "tanimoto.h"
#include "test.h"
#include <stdbool.h>

/*
 * Declare global arrays. Functions defined within this file assume the
 * presence of these global arrays to work. Declared as extern in tanimoto.h
 */
BinaryVector referenceVectors[REF_VECTOR_NO];
BinaryVector comparisonVectors[CMP_VECTOR_NO];
BinaryVector intermediaryVectors[REF_VECTOR_NO*CMP_VECTOR_NO];

TanimotoResult tanimotoResults[REF_VECTOR_NO*CMP_VECTOR_NO];

/* 
 * Function: initVectors
 * Initializes the 115-byte data fields of the global reference and comparison
 * vectors with random values to be used for testing.
 * ID assigned is the same as hardware. ID == 0 is reserved for the accelerator.
 * Weights are initialized to 0 as they are calculated later.
 */
void initVectors(bool generate)
{
    srand((unsigned) time(NULL));

    if (generate) {
        /* Initialize reference vectors */
        for (int i = 0; i < REF_VECTOR_NO; i++) {
            referenceVectors[i].id = i+1;
            referenceVectors[i].weight = 0;

            for (int j = 0; j < 115; j++) {
                referenceVectors[i].data[j] = (uint8_t)(rand() % 256);
            }
        }

        /* Initialize comparison vectors */
        for (int i = 0; i < CMP_VECTOR_NO; i++) {
            comparisonVectors[i].id = i + REF_VECTOR_NO + 1;
            comparisonVectors[i].weight = 0;

            for (int j = 0; j < 115; j++) {
                comparisonVectors[i].data[j] = (uint8_t)(rand() % 256);
            }
        }
    } else {
        /* Use hard-coded test data */
        for(int i = 0; i < 8; i++){
            referenceVectors[i] = testReferenceVectors[i];
        }

        for(int i = 0; i < 24; i++){
            comparisonVectors[i] = testComparisonVectors[i];
        }
    }
}


/*
 * Function: writeVectorsToFile
 * Writes the data[] bytes of the referenceVectors followed immediately
 * by the data[] bytes of the comparisonVectors to a single binary file,
 * with no header or extra information.
 */
int writeVectorsToFile(const char *filename)
{
    FILE *fp = fopen(filename, "wb");
    if (!fp) {
        perror("Failed to open output file");
        return -1;
    }

    /* Write reference vectors' data (115 bytes each) */
    for (int i = 0; i < REF_VECTOR_NO; i++) {
        size_t written = fwrite(referenceVectors[i].data, 
                                sizeof(uint8_t), 
                                115, 
                                fp);
        if (written != 115) {
            perror("Failed to write reference vector data");
            fclose(fp);
            return -1;
        }
    }

    /* Write comparison vectors' data (115 bytes each) */
    for (int i = 0; i < CMP_VECTOR_NO; i++) {
        size_t written = fwrite(comparisonVectors[i].data, 
                                sizeof(uint8_t), 
                                115, 
                                fp);
        if (written != 115) {
            perror("Failed to write comparison vector data");
            fclose(fp);
            return -1;
        }
    }

    fclose(fp);
    return 0;
}


/*
 * Function: writeIDsToFile
 * Writes the contents of tanimotoResults to a binary file with no header
 * or extra information in the following way:
 * {refID[0], cmpID[0]} {refID[1], cmpID[1]} ... {refID[N-1], cmpID[N-1]}
*/
int writeIDsToFile(const char *filename, double threshold)
{
    uint32_t tmp[REF_VECTOR_NO*CMP_VECTOR_NO*2];
    unsigned int cnt = 0;

    FILE *fp = fopen(filename, "wb");
    if (!fp) {
        perror("Failed to open output file");
        return -1;
    }

    for(int i = 0; i < REF_VECTOR_NO*CMP_VECTOR_NO; i++){
        if(tanimotoResults[i].tanimotoCoefficient > threshold){
            tmp[2*cnt]   = tanimotoResults[i].A->id;
            tmp[2*cnt+1] = tanimotoResults[i].B->id;
            cnt++;
        }
    }

    size_t written = fwrite(tmp,
                            sizeof(uint32_t), 
                            cnt*2, 
                            fp);

    if (written != cnt*2) {
        perror("Failed to write comparison vector data");
        fclose(fp);
        return -1;
    }

    fclose(fp);
    return 0;
}


/*
 * Function: createIntermediaryVectors
 * For each pair (ref, cmp), compute the bitwise AND of the 115 data bytes
 * and store it in intermediaryVectors.
 * 
 * The index in intermediaryVectors is (i * CMP_VECTOR_NO + j), where:
 *   i in [0, REF_VECTOR_NO - 1]
 *   j in [0, CMP_VECTOR_NO - 1]
 */
void createIntermediaryVectors(void)
{
    for (int i = 0; i < REF_VECTOR_NO; i++) {
        for (int j = 0; j < CMP_VECTOR_NO; j++) {
            int idx = i * CMP_VECTOR_NO + j; 

            /* Initialize weight to 0 (will be calculated later) */
            intermediaryVectors[idx].weight = 0;

            /* Bitwise AND each byte of the data */
            for (int k = 0; k < 115; k++) {
                intermediaryVectors[idx].data[k] = 
                    referenceVectors[i].data[k] & comparisonVectors[j].data[k];
            }
        }
    }
}


/*
 * Function: calculateBinaryWeight
 * Counts the number of '1' bits in the data[115] array of the input vector
 * and stores this value in the vector's weight field.
 */
void calculateBinaryWeight(BinaryVector *vec)
{
    uint32_t bitCount = 0;
    for (int i = 0; i < 115; i++) {
        bitCount += __builtin_popcount(vec->data[i]);
    }
    vec->weight = bitCount;
}


/*
 * Function: computeTanimotoSimilarity
 * Calculates the Tanimoto similarity between the reference, comparison,
 * and their ANDed intermediary vector. We assume weight fields have already
 * been computed.
 * 
 * TanimotoSimilarity = AND_weight / (ref_weight + cmp_weight - AND_weight).
 */
double computeTanimotoSimilarity(const BinaryVector *ref,
                                 const BinaryVector *cmp,
                                 const BinaryVector *inter)
{
    /* Convert to double to avoid integer division */
    double andWeight  = (double)inter->weight;
    double refWeight  = (double)ref->weight;
    double cmpWeight  = (double)cmp->weight;

    double denominator = (refWeight + cmpWeight - andWeight);

    /* Check for zero denominator just in case */
    if (denominator == 0.0) {
        return 0.0; 
    }

    return 1 - andWeight / denominator;
}


/*
 * Function: computeAllTanimotoSimilarities
 * Iterates over all referenceVector - comparisonVector pairs, along with
 * their corresponding intermediary vector, to compute and store the Tanimoto
 * similarity for each pairing in the global tanimotoResults[] array.
 */
void computeAllTanimotoSimilarities(void)
{
    for (int i = 0; i < REF_VECTOR_NO; i++) {
        for (int j = 0; j < CMP_VECTOR_NO; j++) {
            int idx = i * CMP_VECTOR_NO + j;
            /* Compute Tanimoto using the ref, cmp, and intermediary vectors */
            tanimotoResults[idx].tanimotoCoefficient
                = computeTanimotoSimilarity(&referenceVectors[i], 
                                            &comparisonVectors[j], 
                                            &intermediaryVectors[idx]);
            tanimotoResults[idx].A = &referenceVectors[i];
            tanimotoResults[idx].B = &comparisonVectors[j];
            tanimotoResults[idx].C = &comparisonVectors[idx];
        }
    }
}


/*
 * Function: printResult
 * Prints the referenceVectorID and comparisonVectorID from a TanimotoResult,
 * if the calculated coefficient is less than the given threshold
 */
void printResult(const TanimotoResult result, double threshold)
{
    if(result.tanimotoCoefficient > threshold) {
        printf("refID:\t0x%08x\tcmpID:\t0x%08x\tcoeff:\t%f\n",
               result.A->id,
               result.B->id,
               result.tanimotoCoefficient);

        printf("A: ");
        for(unsigned int i = 0; i < 115; i++){
            printf("%02x", result.A->data[i]);
        }
        printf("\n");

        printf("B: ");
        for(unsigned int i = 0; i < 115; i++){
            printf("%02x", result.B->data[i]);
        }
        printf("\n");

        printf("C: ");
        for(unsigned int i = 0; i < 115; i++){
            printf("%02x", result.C->data[i]);
        }
        printf("\n");
    }
}

/*
 * Function: printAllResultsToTxtFile
 * Export all results to TXT file. Comparison with accelerator output to be done
 * on the targed device
 */
void printAllResultsToTxtFile(const char *filename)
{
    FILE *fp = fopen(filename, "w");
    if (!fp) {
        perror("Error opening output file");
        return;
    }

    for (int i = 0; i < REF_VECTOR_NO * CMP_VECTOR_NO; i++) {
        fprintf(fp, "refID:\t0x%08x\tcmpID:\t0x%08x\tcoeff:\t%f\tCNT[A]:\t%d\tCNT[B]\t%d\tCNT[C]\t%d\n",
                tanimotoResults[i].A->id,
                tanimotoResults[i].B->id,
                tanimotoResults[i].tanimotoCoefficient,
                tanimotoResults[i].A->weight,
                tanimotoResults[i].B->weight,
                tanimotoResults[i].C->weight
        );
    }

    fclose(fp);
}
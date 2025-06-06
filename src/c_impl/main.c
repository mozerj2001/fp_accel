#include "tanimoto.h"
#include <stdbool.h>

int main(int argc, char *argv[])
{
    // Handle commandline arguments
    char* fnameVectors = "vectors.bin";
    char* fnameResults = "results.bin";
    char* fnameResultsTxt = "results.txt";
    bool printResults = false;
    bool generate = false;

    static struct option long_opts[] = {
        // name             has_arg               flag  short-val
        { "vectors",        required_argument   , NULL, 'v' },
        { "results",        required_argument   , NULL, 'r' },
        { "results-txt",    required_argument   , NULL, 't' },
        { "print",          no_argument         , NULL, 'p' },
        { "generate",       no_argument         , NULL, 'g' },
        { NULL,             0                   , NULL,  0  }
    };

    int opt;
    while ((opt = getopt_long(argc, argv, "v:r:t:pg", long_opts, NULL)) != -1) {
        switch (opt) {
            case 'v':
                fnameVectors = optarg;
                break;
            case 'r':
                fnameResults = optarg;
                break;
            case 't':
                fnameResultsTxt = optarg;
                break;
            case 'p':
                printResults = true;
                break;
            case 'g':
                generate = true;
                break;
            default:
                fprintf(stderr,
                        "Usage: %s [--vectors file] [--results file] [--results-txt file] [--print] [--generate]\n",
                        argv[0]);
                return -1;
        }
    }

    // Create random vectors
    initVectors(generate);

    // Export random vectors to binary file, to be read by the accelerator OCL kernel
    if (writeVectorsToFile(fnameVectors) != 0) {
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
    if (printResults) {
        for(int i = 0; i < REF_VECTOR_NO * CMP_VECTOR_NO; i++) {
            printResult(tanimotoResults[i], THRESHOLD);
        }
    }

    printAllResultsToTxtFile(fnameResultsTxt);

    writeIDsToFile(fnameResults, THRESHOLD);

    return 0;
}
#ifndef GLOBALS_H
#define GLOBALS_H

/*
 * Constants: Global Constants
 * Global constants determined at compile time.
 * 
 * VECTOR_WIDTH             - Number of bits in a full 1D binary vector.
 * VECTOR_SIZE              - Number of bytes in a full binary vector (VECTOR_WIDTH/8).
 * REF_VEC_NO               - Number of reference vectors to compare the dataset with.
 * CMP_VEC_NO               - Number of compare vectors to compare against reference vectors.
 * ID_SIZE                  - Number of bytes in a vector ID.
 * MEMORY_BUS_WIDTH_BYTES   - Number of bytes on the memory data bus (16 for ZynqMP, 64 for Versal).
 * MEMORY_BUS_WIDTH_BITS    - Number of bits ont he memory data bus (128 for ZynqMP, 512 for Versal).
 * 
 */

extern const unsigned int VECTOR_WIDTH;
extern const unsigned int VECTOR_SIZE;
extern const unsigned int REF_VEC_NO;
extern const unsigned int CMP_VEC_NO;
extern const unsigned int ID_SIZE;
extern const unsigned int MEMORY_BUS_WIDTH_BYTES;
extern const unsigned int MEMORY_BUS_WIDTH_BITS;

#endif // GLOBALS_H
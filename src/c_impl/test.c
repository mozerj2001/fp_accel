#include "test.h"
#include "tanimoto.h"

// Example: 8 reference and 24 comparison vectors. Expand as needed.
const BinaryVector testReferenceVectors[8] = {
    { .id = 1, .weight = 0, .data = { [0 ... 114] = 0x00 } },
    { .id = 2, .weight = 0, .data = { [0 ... 114] = 0x11 } },
    { .id = 3, .weight = 0, .data = { [0 ... 114] = 0x33 } },
    { .id = 4, .weight = 0, .data = { [0 ... 114] = 0x55 } },
    { .id = 5, .weight = 0, .data = { [0 ... 114] = 0x77 } },
    { .id = 6, .weight = 0, .data = { [0 ... 114] = 0x99 } },
    { .id = 7, .weight = 0, .data = { [0 ... 114] = 0xDD } },
    { .id = 8, .weight = 0, .data = { [0 ... 114] = 0xFF } },
};

const BinaryVector testComparisonVectors[24] = {
    { .id = 9,  .weight = 0, .data = { [0 ... 114] = 0x00 } },
    { .id = 10, .weight = 0, .data = { [0 ... 114] = 0x11 } },
    { .id = 11, .weight = 0, .data = { [0 ... 114] = 0x22 } },
    { .id = 12, .weight = 0, .data = { [0 ... 114] = 0x33 } },
    { .id = 13, .weight = 0, .data = { [0 ... 114] = 0x44 } },
    { .id = 14, .weight = 0, .data = { [0 ... 114] = 0x55 } },
    { .id = 15, .weight = 0, .data = { [0 ... 114] = 0x66 } },
    { .id = 16, .weight = 0, .data = { [0 ... 114] = 0x77 } },
    { .id = 17, .weight = 0, .data = { [0 ... 114] = 0x88 } },
    { .id = 18, .weight = 0, .data = { [0 ... 114] = 0x99 } },
    { .id = 19, .weight = 0, .data = { [0 ... 114] = 0xAA } },
    { .id = 20, .weight = 0, .data = { [0 ... 114] = 0xBB } },
    { .id = 21, .weight = 0, .data = { [0 ... 114] = 0xCC } },
    { .id = 22, .weight = 0, .data = { [0 ... 114] = 0xDD } },
    { .id = 23, .weight = 0, .data = { [0 ... 114] = 0xEE } },
    { .id = 24, .weight = 0, .data = { [0 ... 114] = 0xFF } },
    { .id = 25, .weight = 0, .data = { [0 ... 114] = 0x2A } },
    { .id = 26, .weight = 0, .data = { [0 ... 114] = 0x2B } },
    { .id = 27, .weight = 0, .data = { [0 ... 114] = 0x3C } },
    { .id = 28, .weight = 0, .data = { [0 ... 114] = 0x4D } },
    { .id = 29, .weight = 0, .data = { [0 ... 114] = 0x5E } },
    { .id = 30, .weight = 0, .data = { [0 ... 114] = 0x6F } },
    { .id = 31, .weight = 0, .data = { [0 ... 114] = 0x70 } },
    { .id = 32, .weight = 0, .data = { [0 ... 114] = 0x81 } }
};

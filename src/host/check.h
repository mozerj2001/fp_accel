#ifndef CHECK_H
#define CHECK_H

#include <cstdint>

struct IDPair {
    uint32_t ref_id;
    uint32_t cmp_id;
};

struct ComparisonResult {
    IDPair* missing_expected;    // IDs that were expected but not found in results
    IDPair* unexpected_results;  // IDs that were in results but not expected
    IDPair* duplicate_results;   // IDs that appeared more than once in results
    int missing_count;
    int unexpected_count;
    int duplicate_count;
};

ComparisonResult compareResults(
    const IDPair* expected,
    const IDPair* results,
    int expected_count,
    int result_count
);

void freeComparisonResult(ComparisonResult& result);

int dumpCheckResults(
    const ComparisonResult& result,
    const char* filename
);

#endif // CHECK_H

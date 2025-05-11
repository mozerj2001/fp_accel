#include "check.h"
#include <iostream>
#include <cstdint>
#include <unordered_map>
#include <cstring>

// Custom hash function for IDPair
struct IDPairHash {
    size_t operator()(const IDPair& pair) const {
        // Combine both IDs into a single hash
        return std::hash<uint32_t>()(pair.ref_id) ^ 
               (std::hash<uint32_t>()(pair.cmp_id) << 1);
    }
};

// Custom equality operator for IDPair
struct IDPairEqual {
    bool operator()(const IDPair& lhs, const IDPair& rhs) const {
        return lhs.ref_id == rhs.ref_id && lhs.cmp_id == rhs.cmp_id;
    }
};

// Function: compareResults
// expected - array containing the expected IDs to check against (must be unique)
// results - array containing the actual result IDs to verify
// expected_size - number of elements in expected array
// results_size - number of elements in results array
// Description: Compares two arrays of IDs. Expected IDs must be unique. Returns a structure
// containing lists of missing expected values, unexpected results, and duplicate results.
// The returned structure contains dynamically allocated arrays that must be freed by the caller.
ComparisonResult compareResults(
    const IDPair* expected,
    const IDPair* results,
    int expected_count,
    int result_count
) {
    ComparisonResult comparison = {nullptr, nullptr, nullptr, 0, 0, 0};
    
    // Create a set of expected pairs for quick lookup
    std::unordered_map<IDPair, int, IDPairHash, IDPairEqual> expected_pairs;
    for (int i = 0; i < expected_count; i++) {
        expected_pairs[expected[i]] = 1;
    }
    
    // Count occurrences of each result and track unexpected ones
    std::unordered_map<IDPair, int, IDPairHash, IDPairEqual> result_counts;
    for (int i = 0; i < result_count; i++) {
        result_counts[results[i]]++;
        if (expected_pairs.find(results[i]) == expected_pairs.end()) {
            comparison.unexpected_count++;
        }
    }

    // Find missing expected values
    for (int i = 0; i < expected_count; i++) {
        if (result_counts[expected[i]] == 0) {
            comparison.missing_count++;
        }
    }
    
    // Find duplicates
    for (const auto& pair : result_counts) {
        if (pair.second > 1) {
            comparison.duplicate_count++;
        }
    }
    
    // Allocate arrays for results
    if (comparison.missing_count > 0) {
        comparison.missing_expected = new IDPair[comparison.missing_count];
    }
    if (comparison.unexpected_count > 0) {
        comparison.unexpected_results = new IDPair[comparison.unexpected_count];
    }
    if (comparison.duplicate_count > 0) {
        comparison.duplicate_results = new IDPair[comparison.duplicate_count];
    }
    
    // Fill missing expected array
    int missing_idx = 0;
    for (int i = 0; i < expected_count; i++) {
        if (result_counts[expected[i]] == 0) {
            comparison.missing_expected[missing_idx++] = expected[i];
        }
    }
    
    // Fill unexpected results array
    int unexpected_idx = 0;
    for (const auto& pair : result_counts) {
        if (expected_pairs.find(pair.first) == expected_pairs.end()) {
            comparison.unexpected_results[unexpected_idx++] = pair.first;
        }
    }
    
    // Fill duplicate results array
    int duplicate_idx = 0;
    for (const auto& pair : result_counts) {
        if (pair.second > 1) {
            comparison.duplicate_results[duplicate_idx++] = pair.first;
        }
    }
    
    return comparison;
}

// Function: freeComparisonResult
// result - ComparisonResult structure to free
// Description: Frees the dynamically allocated arrays in a ComparisonResult structure
void freeComparisonResult(ComparisonResult& result) {
    delete[] result.missing_expected;
    delete[] result.unexpected_results;
    delete[] result.duplicate_results;
    
    result.missing_expected = nullptr;
    result.unexpected_results = nullptr;
    result.duplicate_results = nullptr;
    result.missing_count = 0;
    result.unexpected_count = 0;
    result.duplicate_count = 0;
}

// Function: dumpCheckResults
// result - ComparisonResult structure containing the comparison results
// filename - Name of the file to write results to
// Returns: 0 on success, 1 on failure
int dumpCheckResults(const ComparisonResult& result, const char* filename) {
    
    int match = 0;

    FILE* fp = fopen(filename, "w");

    if (!fp) {
        std::cout << "[ERROR][FILE_OPS] Failed to open comparison results file: " << filename << std::endl;
        return 1;
    }

    if (result.missing_count > 0) {
        fprintf(fp, "Missing expected ID pairs (%d):\n", result.missing_count);
        for (int i = 0; i < result.missing_count; i++) {
            fprintf(fp, "  Ref ID: 0x%08x, Cmp ID: 0x%08x\n", 
                result.missing_expected[i].ref_id,
                result.missing_expected[i].cmp_id);
        }
        match = 1;
    }
    
    if (result.duplicate_count > 0) {
        fprintf(fp, "Duplicate ID pairs in results (%d):\n", result.duplicate_count);
        for (int i = 0; i < result.duplicate_count; i++) {
            fprintf(fp, "  Ref ID: 0x%08x, Cmp ID: 0x%08x\n",
                result.duplicate_results[i].ref_id,
                result.duplicate_results[i].cmp_id);
        }
        match = 1;
    }
    
    fclose(fp);
    return match;
}

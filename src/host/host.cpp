#include <fstream>
#include <iostream>
#include <bitset>
#include <stdlib.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <unistd.h>
#include "host.h"
#include <CL/cl2.hpp>

/*  ################################
 *  DEFINES
 */

// Threshold RAM address limits
#define BRAM_BASEADDR 0x82000000    // BRAM base address
#define BRAM_MAXADDR 0x82001FFF     // BRAM region upper limit as integer pointer
#define BRAM_IO_SIZE 32768          // BRAM region size in bytes

// Define Tanimoto threshold
#define THRESHOLD 0.31

// Macro that submits OpenCL calls, then checks whether an error has occurred.
#define OCL_CHECK(error, call)                                                                   \
    call;                                                                                        \
    if (error != CL_SUCCESS) {                                                                   \
        printf("[ERROR][OCL_CHECK] %s:%d Error calling " #call ", error code is: %d\n", __FILE__, __LINE__, error); \
        exit(EXIT_FAILURE);                                                                      \
    }

/*  ################################
 *  GLOBAL CONSTANTS
 */

static const unsigned int VECTOR_WIDTH = 920;
static const unsigned int VECTOR_SIZE = 115;     // 920 bits == 115 bytes
static const unsigned int REF_VEC_NO = 8;
static const unsigned int CMP_VEC_NO = 92;
static const unsigned int ID_SIZE = 1;           // ID_WIDTH in bytes
static const unsigned int MEMORY_BUS_WIDTH_BYTES = 16;
static const unsigned int MEMORY_BUS_WIDTH_BITS = 128;

/*  ################################
 *  FUNCTION DECLARATIONS
 */

int configure_threshold_ram();

int readVectorsFromFile(
    uint8_t* ptr_ref,
    uint8_t* ptr_cmp,
    const char* filename
);

size_t  readIDsFromFile(
    uint32_t** buf_in,
    const char* filename
);

void extractExpectedIDs(
    unsigned int _no_exp_ids,
    uint32_t*    _raw_id_exp,
    uint32_t**   ref_id_exp_,
    uint32_t**   cmp_id_exp_
);

unsigned int countOutputIDs(
    uint8_t* _id_buf
);

void extractResults(
    unsigned int _no_result_ids,
    uint8_t*     _result_buffer,
    uint32_t**   ref_id_result_,
    uint32_t**   cmp_id_result_
);

void dumpIDs(
    unsigned int _exp_id_num,
    uint32_t* _ref_id_exp,
    uint32_t* _cmp_id_exp,
    unsigned int _result_id_num,
    uint32_t* _ref_id_result,
    uint32_t* _cmp_id_result
);

/*  ################################
 *  MAIN
 *  --> read vectors from binary file
 *  --> push to accelerator
 *  --> compare results
 */

int main(int argc, char* argv[]) {


    // TARGET_DEVICE macro needs to be passed from gcc command line
    if (argc != 2) {
        std::cout << "Usage: " << argv[0] << " <xclbin>" << std::endl;
        return EXIT_FAILURE;
    }

    std::string xclbinFilename = argv[1];

    // Vector buffer sizes in bytes
    size_t ref_buf_size = REF_VEC_NO * VECTOR_SIZE;
    size_t cmp_buf_size = CMP_VEC_NO * VECTOR_SIZE;
    size_t id_pair_size = REF_VEC_NO * CMP_VEC_NO * ID_SIZE * 2;

    // how many bus cycles are required to transfer REF_VEC_NO + CMP_VEC_NO vectors? (round up)
    unsigned int ref_bus_cycle_no = (ref_buf_size + MEMORY_BUS_WIDTH_BYTES -1)*8 / MEMORY_BUS_WIDTH_BITS;
    unsigned int cmp_bus_cycle_no = (cmp_buf_size + MEMORY_BUS_WIDTH_BYTES -1)*8 / MEMORY_BUS_WIDTH_BITS;

    // Creates a vector of DATA_SIZE elements with an initial value of 10 and 32
    // using customized allocator for getting buffer alignment to 4k boundary

    std::vector<cl::Device> devices;            // vector of device objects
    cl_int err;
    cl::Context context;
    cl::CommandQueue q;
    cl::Kernel tanimoto_krnl;
    cl::Program program;
    std::vector<cl::Platform> platforms;        // vector of platform objects
    bool found_device = false;

    // Find targeted device on Xilinx platform.
    cl::Platform::get(&platforms);
    for (size_t i = 0; (i < platforms.size()) & (found_device == false); i++) {
        cl::Platform platform = platforms[i];
        std::string platformName = platform.getInfo<CL_PLATFORM_NAME>();
        if (platformName == "Xilinx") {
            devices.clear();
            platform.getDevices(CL_DEVICE_TYPE_ACCELERATOR, &devices);
            if (devices.size()) {
                found_device = true;
                break;
            }
        }
    }
    if (found_device == false) {
        std::cout << "[ERROR][DEVICE] Unable to find Target Device " << std::endl;
        return EXIT_FAILURE;
    }

    std::cout << "[INFO] Opening " << xclbinFilename << std::endl;
    FILE* fp;
    if ((fp = fopen(xclbinFilename.c_str(), "r")) == nullptr) {
        printf("[ERROR][FILE_OPS] %s xclbin not available please run <make xclbin> in the project root directory.\n", xclbinFilename.c_str());
        exit(EXIT_FAILURE);
    }
    // Load xclbin
    std::cout << "Loading: '" << xclbinFilename << "'\n";
    std::ifstream bin_file(xclbinFilename, std::ifstream::binary);
    bin_file.seekg(0, bin_file.end);
    unsigned nb = bin_file.tellg();
    bin_file.seekg(0, bin_file.beg);
    char* buf = new char[nb];
    bin_file.read(buf, nb);

    // Creating Program from Binary File
    cl::Program::Binaries bins;
    bins.push_back({buf, nb});
    bool valid_device = false;
    for (unsigned int i = 0; i < devices.size(); i++) {
        auto device = devices[i];
        // Creating Context and Command Queue for selected Device
        OCL_CHECK(err, context = cl::Context(device, nullptr, nullptr, nullptr, &err));
        OCL_CHECK(err, q = cl::CommandQueue(context, device, CL_QUEUE_PROFILING_ENABLE, &err));
        std::cout << "[INFO] Attempting to program device[" << i << "]: " << device.getInfo<CL_DEVICE_NAME>() << std::endl;
        cl::Program program(context, {device}, bins, nullptr, &err);
        if (err != CL_SUCCESS) {
            std::cout << "[ERROR][DEVICE] Failed to program device[" << i << "] with xclbin file!\n";
        } else {
            std::cout << "[INFO] Device[" << i << "]: program successful!\n";
            OCL_CHECK(err, tanimoto_krnl = cl::Kernel(program, "hls_dma", &err));       // hls_dma is the visible interface of the kernel
            valid_device = true;
            break; // we break because we found a valid device
        }
    }
    if (!valid_device) {
        std::cout << "[ERROR][DEVICE] Failed to program any device found, exit!\n";
        exit(EXIT_FAILURE);
    }

    // These commands will allocate memory on the Device. The cl::Buffer objects can
    // be used to reference the memory locations on the device.
    uint8_t id_pair_buffer_init[id_pair_size] = {};

    printf("[INFO] Setting up OCL buffer objects with buffer sizes:\nref_buf_size = %d\tcmp_buf_size = %d\tid_pair_size = %d\n",
        ref_buf_size, cmp_buf_size, id_pair_size);
    OCL_CHECK(err, cl::Buffer
        vec_ref_buffer(context, CL_MEM_READ_ONLY, ref_buf_size, NULL, &err));
    OCL_CHECK(err, cl::Buffer
        cmp_ref_buffer(context, CL_MEM_READ_ONLY, cmp_buf_size, NULL, &err));
    OCL_CHECK(err, cl::Buffer
        id_pair_buffer(context, CL_MEM_WRITE_ONLY | CL_MEM_COPY_HOST_PTR, id_pair_size, id_pair_buffer_init, &err));

    // set the kernel Arguments
    std::cout << "[INFO] Setting up kernel arguments.\n";
    OCL_CHECK(err, err = tanimoto_krnl.setArg(0, vec_ref_buffer));
    OCL_CHECK(err, err = tanimoto_krnl.setArg(1, cmp_ref_buffer));
    OCL_CHECK(err, err = tanimoto_krnl.setArg(4, id_pair_buffer));
    OCL_CHECK(err, err = tanimoto_krnl.setArg(5, ref_bus_cycle_no));
    OCL_CHECK(err, err = tanimoto_krnl.setArg(6, cmp_bus_cycle_no));

    // We then need to map our OpenCL buffers to get the pointers
    uint32_t* ptr_ref;
    uint32_t* ptr_cmp;
    uint32_t* ptr_idp;

    std::cout << "[INFO] Mapping OCL buffers to pointers.\n";
    OCL_CHECK(err, ptr_ref =
        (uint32_t*)q.enqueueMapBuffer(vec_ref_buffer, CL_TRUE, CL_MAP_WRITE, 0, ref_buf_size, NULL, NULL, &err));
    OCL_CHECK(err, ptr_cmp =
        (uint32_t*)q.enqueueMapBuffer(cmp_ref_buffer, CL_TRUE, CL_MAP_WRITE, 0, cmp_buf_size, NULL, NULL, &err));
    OCL_CHECK(err, ptr_idp =
        (uint32_t*)q.enqueueMapBuffer(id_pair_buffer, CL_TRUE, CL_MAP_READ, 0, id_pair_size, NULL, NULL, &err));

    // Load data/randomize in place
    if(readVectorsFromFile((uint8_t*) ptr_ref, (uint8_t*) ptr_cmp, "vectors.bin")) {
        std::cout << "[WARNING] Test data could not be loaded, continuing with random data.\n";
        for (int i = 0; i < (int) ref_buf_size/sizeof(int); i++) {
            ptr_ref[i] = rand() % RAND_MAX;
        }
        for (int i = 0; i < (int) cmp_buf_size/sizeof(int); i++) {
            ptr_cmp[i] = rand() % RAND_MAX;
        }
    }

    // Copy buffers to kernel memory space
    std::cout << "[INFO] Copy input buffers to the kernel's memory space.\n";
    OCL_CHECK(err, err = q.enqueueMigrateMemObjects({vec_ref_buffer, cmp_ref_buffer}, 0 /* 0 means from host*/));

    // Configure threshold BRAM
    if(configure_threshold_ram()){
        std::cout << "[ERROR][CFG_THRESHOLD] Someting went wrong when accessing the memory mapped threshold BRAMs.\n";
    }

    // Launch the Kernel
    printf("[INFO] Launch kernel with arguments:\nref_bus_cycle_no = %d\tcmp_bus_cycle_no = %d\n",
        ref_bus_cycle_no, cmp_bus_cycle_no);
    OCL_CHECK(err, err = q.enqueueTask(tanimoto_krnl));

    // Cpoy ID pair to host memory space
    std::cout << "[INFO] Read output into host memory.\n";
    OCL_CHECK(err, q.enqueueMigrateMemObjects({id_pair_buffer}, CL_MIGRATE_MEM_OBJECT_HOST));  

    std::cout << "[INFO] Wait for the OpenCL queue to finish.\n";
    OCL_CHECK(err, q.finish());

    // CHECK RESULTS AGAINST EXPECTED RESULTS

    int match = 0;      // Expect success

                                    // HW accel results stored in id_pair_buffer, interleaved, raw binary
    uint32_t* expected_id_pairs;    // odd idx: expected ref ID, even idx: expected cmp ID
    uint32_t* ref_id_exp;           // expected ref IDs in order, each ref ID corresponds to its pair in cmp_id_exp
    uint32_t* cmp_id_exp;
    uint32_t* ref_id_result;        // accelerator output ref IDs, each ref ID corresponds to its pair in cmp_id_result
    uint32_t* cmp_id_result;

    int no_of_exp_ids = readIDsFromFile(&expected_id_pairs, "results.bin");
    int no_of_result_ids = countOutputIDs((uint8_t*) ptr_idp);

    if(no_of_exp_ids != no_of_result_ids){
        std::cout << "[WARNING] Number of expected IDs doesn't match number of results!" << std::endl;
    }

    extractExpectedIDs(
        no_of_exp_ids,
        expected_id_pairs,
        &ref_id_exp,
        &cmp_id_exp
    );

    extractResults(
        no_of_result_ids,
        (uint8_t*) ptr_idp,
        &ref_id_result,
        &cmp_id_result
    );

    // Verify the result --> Just check if we are getting data at all for now
    /* ... CHECKING ... */

    std::cout << "[INFO] Free buffers.\n";
    OCL_CHECK(err, err = q.enqueueUnmapMemObject(vec_ref_buffer, ptr_ref));
    OCL_CHECK(err, err = q.enqueueUnmapMemObject(cmp_ref_buffer, ptr_cmp));
    OCL_CHECK(err, err = q.enqueueUnmapMemObject(id_pair_buffer, ptr_idp));
    OCL_CHECK(err, err = q.finish());

    free(expected_id_pairs);
    free(ref_id_exp);
    free(cmp_id_exp);
    free(ref_id_result);
    free(cmp_id_result);

    std::cout << "[INFO] TEST FINISHED!\t##################" << std::endl;
    return (match ? EXIT_FAILURE : EXIT_SUCCESS);

}


/*  ################################
 *  FUNCTION DEFINITIONS
 */

// FUNCTION: Load division results to the threshold BRAM in the comparator module
// See documentation on how this avoids doing division in the PL
// Use /dev/mem and mmap to access memory mapped IO in physical memory
int configure_threshold_ram(){
    int mem_fp = open("/dev/mem", O_RDWR | O_SYNC);
    if(mem_fp < 0){
        std::cout << "[ERROR][CFG_THRESHOLD] Cannot open /dev/mem.\n";
        return 1;
    }

    void *mem = mmap(0, BRAM_IO_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, mem_fp, BRAM_BASEADDR);
    if (mem == MAP_FAILED){
        std::cout << "[ERROR][CFG_THRESHOLD] mmap() call failed, cannot access BRAM IO!\n";
        close(mem_fp);
        return 1;
    }

    // Configure threshold RAM
    unsigned int *bram = (unsigned int*) mem;
    for(unsigned int cnt_c = 0; cnt_c <= VECTOR_WIDTH; cnt_c++){
        *(bram + cnt_c) = (unsigned int) (cnt_c * (2.0-THRESHOLD)/(1.0-THRESHOLD));
    }
    
    munmap(mem, BRAM_IO_SIZE);
    close(mem_fp);
    return 0;
}

// FUNCTION: Read pre-generated binary test vectors.
// Input file "vectors.bin" assumed to be present in working directory for now.
int readVectorsFromFile(uint8_t *ptr_ref, uint8_t *ptr_cmp, const char *filename)
{
    FILE *fp = fopen(filename, "rb");
    if (fp == NULL) {
        perror("[ERROR][FILE_OPS] Error opening vectors file");
        return 1;
    }

    size_t refBytes = REF_VEC_NO * 115;
    size_t cmpBytes = CMP_VEC_NO * 115;

    /* Read reference vectors (refBytes total) */
    size_t bytesRead = fread(ptr_ref, sizeof(uint8_t), refBytes, fp);
    if (bytesRead != refBytes) {
        perror("[ERROR][FILE_OPS] Error reading reference vectors");
        fclose(fp);
        return 1;
    }

    /* Read comparison vectors (cmpBytes total) */
    bytesRead = fread(ptr_cmp, sizeof(uint8_t), cmpBytes, fp);
    if (bytesRead != cmpBytes) {
        perror("[ERROR][FILE_OPS] Error reading comparison vectors");
        fclose(fp);
        return 1;
    }

    fclose(fp);
    return 0;
}

// FUNCTION: Read pre-calculated ID pairs.
// Input file "results.bin" assumed to be present in the working directory for now.
size_t  readIDsFromFile(uint32_t** buf_out, const char* filename)
{
    size_t bytes;
    size_t read;
    uint32_t *buf_in;

    std::cout << "[INFO] Read pre-calculated IDs from results file." << std::endl;

    FILE *fp = fopen(filename, "rb");
    if (fp == NULL) {
        perror("[ERROR][FILE_OPS] Error opening results file");
        return 1;
    }

    if (fseek(fp, 0, SEEK_END) != 0) {
        perror("[ERROR][FILE_OPS] Error seeking results file!");
        fclose(fp);
        return -1;
    }

    bytes = ftell(fp);
    if (bytes < 0) {
        perror("[ERROR][FILE_OPS] Error telling pointer position of results file!");
        fclose(fp);
        return -1;
    }

    if ((bytes % sizeof(uint32_t)) != 0) {
        perror("[ERROR][FILE_OPS] Unexpected number of bytes in results file!");
        fclose(fp);
        return -1;
    }

    rewind(fp);

    buf_in = (uint32_t*) malloc(bytes);
    read = fread(buf_in, 1, bytes, fp);
    if (read != bytes) {
        perror("[ERROR][FILE_OPS] Unexpected number of bytes read from reasults file!");
        fclose(fp);
        free(buf_in);
        return -1;
    }

    fclose(fp);
    *buf_out = buf_in;

    return bytes / sizeof(uint32_t);
}

// FUNCTION: Separate expected IDs from interleaved array read from file.
void extractExpectedIDs(
    unsigned int _no_exp_ids,
    uint32_t*    _raw_id_exp,
    uint32_t**   ref_id_exp_,
    uint32_t**   cmp_id_exp_
){

    std::cout << "[INFO] Uninterleaving expected ID array." << std::endl;

    uint32_t* ref_id_exp = (uint32_t*) malloc(_no_exp_ids/2 * sizeof(uint32_t));
    uint32_t* cmp_id_exp = (uint32_t*) malloc(_no_exp_ids/2 * sizeof(uint32_t));

    for(unsigned int i = 0; i < _no_exp_ids/2; i++){
        ref_id_exp[i] = _raw_id_exp[2*i];
        cmp_id_exp[i] = _raw_id_exp[2*i+1];
    }

    *ref_id_exp_ = ref_id_exp;
    *cmp_id_exp_ = cmp_id_exp;

}

// FUNCTION: Count number of result IDs to be un-interleaved.
unsigned int countOutputIDs(
    uint8_t* _id_buf
){

    bool current_id_is_zero = false;
    unsigned int cnt = 0;

    // Look for two consecutive zeroes
    while(!current_id_is_zero){
        current_id_is_zero = true;

        for(unsigned int i = 0; i < ID_SIZE*2; i++){
            if(_id_buf[ID_SIZE*cnt+i] != 0){
                current_id_is_zero = false;
            }
        }

        cnt += 2;
    }

    return cnt-2;
}

// FUNCTION: Extract IDs from the result buffer.
// -- x-byte wide IDs will be extracted to uint32_t integers
// -- IDs to be un-interleaved into two arrays
void extractResults(
    unsigned int _no_result_ids,
    uint8_t*     _result_buffer,
    uint32_t**   ref_id_result_,
    uint32_t**   cmp_id_result_
){
    uint32_t tmp = 0;
    uint32_t tmp_interleaved_buf[_no_result_ids];
    uint32_t* ref_id_result = (uint32_t*) malloc(_no_result_ids/2 * sizeof(uint32_t));
    uint32_t* cmp_id_result = (uint32_t*) malloc(_no_result_ids/2 * sizeof(uint32_t));

    for(unsigned int id = 0; id < _no_result_ids; id++){
        for(unsigned int j = 0; j < ID_SIZE; j++){
            tmp += (uint32_t) _result_buffer[id*ID_SIZE+j];
            tmp << (ID_SIZE-j-1)*8;
        }

        tmp_interleaved_buf[id] = tmp;
        tmp = 0;
    }

    for(unsigned int i = 0; i < _no_result_ids/2; i++){
        ref_id_result[i] = tmp_interleaved_buf[2*i];
        cmp_id_result[i] = tmp_interleaved_buf[2*i+1];
    }

    *ref_id_result_ = ref_id_result;
    *cmp_id_result_ = cmp_id_result;

}


// FUNCTION: Write ID pairs to text file for manual comparison.
void dumpIDs(
    unsigned int _exp_id_num,
    uint32_t* _ref_id_exp,
    uint32_t* _cmp_id_exp,
    unsigned int _result_id_num,
    uint32_t* _ref_id_result,
    uint32_t* _cmp_id_result
){
    FILE* fp = fopen("id_dump.txt", "w");

    if (!fp) {
        perror("[ERROR][FILE_OPS] Failed to open ID dump TXT file!");
        return;
    }

    fprintf(fp, "EXPECTED ID PAIRS ################################\n");
    for(unsigned int i = 0; i < _exp_id_num/2; i++){
        fprintf(fp, "%08x\t%08x\n", _ref_id_exp[i], _cmp_id_exp[i]);
    }

    fprintf(fp, "ACTUAL ID PAIRS ################################\n");
    for(unsigned int i = 0; i < _result_id_num/2; i++){
        fprintf(fp, "%08x\t%08x\n", _ref_id_result[i], _cmp_id_result[i]);
    }

    fclose(fp);

}

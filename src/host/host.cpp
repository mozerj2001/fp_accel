#include <fstream>
#include <iostream>
#include <bitset>
#include <stdlib.h>
#include "host.h"

// Threshold RAM address limits
#define BRAM_BASEADDR 0x82000000
#define BRAM_MAXADDR 0x82001FFF

// Define Tanimoto threshold
#define THRESHOLD 0.33

// Macro that submits OpenCL calls, then checks whether an error has occurred.
#define OCL_CHECK(error, call)                                                                   \
    call;                                                                                        \
    if (error != CL_SUCCESS) {                                                                   \
        printf("%s:%d Error calling " #call ", error code is: %d\n", __FILE__, __LINE__, error); \
        exit(EXIT_FAILURE);                                                                      \
    }

static const int VECTOR_WIDTH = 920;
static const int VECTOR_SIZE = 115;     // 920 bits == 115 bytes
static const int REF_VECTOR_NO = 32;
static const int CMP_VECTOR_NO = 128;
static const int ID_SIZE = 1;           // ID_WIDTH in bytes

// See documentation on how this avoids doing division in the PL
void configure_threshold_ram(){
    unsigned int* bram = (unsigned int*) BRAM_BASEADDR;
    for(unsigned int cnt_c = 0; cnt_c <= VECTOR_WIDTH; cnt_c++){
        bram[cnt_c] = (unsigned int) (cnt_c * (2.0-THRESHOLD)/(1.0-THRESHOLD));
    }
}


int main(int argc, char* argv[]) {
    // TARGET_DEVICE macro needs to be passed from gcc command line
    if (argc != 2) {
        std::cout << "Usage: " << argv[0] << " <xclbin>" << std::endl;
        return EXIT_FAILURE;
    }

    std::string xclbinFilename = argv[1];

    // Vector buffer sizes in bytes
    size_t ref_buf_size = REF_VECTOR_NO * VECTOR_SIZE;
    size_t cmp_buf_size = CMP_VECTOR_NO * VECTOR_SIZE;
    size_t id_pair_size = REF_VECTOR_NO * CMP_VECTOR_NO * ID_SIZE * 2;

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
        std::cout << "Error: Unable to find Target Device " << std::endl;
        return EXIT_FAILURE;
    }

    std::cout << "INFO: Opening " << xclbinFilename << std::endl;
    FILE* fp;
    if ((fp = fopen(xclbinFilename.c_str(), "r")) == nullptr) {
        printf("ERROR: %s xclbin not available please run <make xclbin> in the project root directory.\n", xclbinFilename.c_str());
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
        std::cout << "Attempting to program device[" << i << "]: " << device.getInfo<CL_DEVICE_NAME>() << std::endl;
        cl::Program program(context, {device}, bins, nullptr, &err);
        if (err != CL_SUCCESS) {
            std::cout << "Failed to program device[" << i << "] with xclbin file!\n";
        } else {
            std::cout << "Device[" << i << "]: program successful!\n";
            OCL_CHECK(err, tanimoto_krnl = cl::Kernel(program, "krnl_vadd", &err));
            valid_device = true;
            break; // we break because we found a valid device
        }
    }
    if (!valid_device) {
        std::cout << "ERROR: Failed to program any device found, exit!\n";
        exit(EXIT_FAILURE);
    }

    // These commands will allocate memory on the Device. The cl::Buffer objects can
    // be used to reference the memory locations on the device.
    OCL_CHECK(err, cl::Buffer vec_ref_buffer(context, CL_MEM_READ_ONLY, ref_buf_size, NULL, &err));
    OCL_CHECK(err, cl::Buffer cmp_ref_buffer(context, CL_MEM_READ_ONLY, cmp_buf_size, NULL, &err));
    OCL_CHECK(err, cl::Buffer id_pair_buffer(context, CL_MEM_WRITE_ONLY, id_pair_size, NULL, &err));

    // set the kernel Arguments
    int narg = 0;
    OCL_CHECK(err, err = tanimoto_krnl.setArg(narg++, vec_ref_buffer));
    OCL_CHECK(err, err = tanimoto_krnl.setArg(narg++, cmp_ref_buffer));
    OCL_CHECK(err, err = tanimoto_krnl.setArg(narg++, id_pair_buffer));

    // We then need to map our OpenCL buffers to get the pointers
    int* ptr_ref;
    int* ptr_cmp;
    int* ptr_idp;
    OCL_CHECK(err,
              ptr_ref = (int*)q.enqueueMapBuffer(vec_ref_buffer, CL_TRUE, CL_MAP_WRITE, 0, ref_buf_size, NULL, NULL, &err));
    OCL_CHECK(err,
              ptr_cmp = (int*)q.enqueueMapBuffer(cmp_ref_buffer, CL_TRUE, CL_MAP_WRITE, 0, cmp_buf_size, NULL, NULL, &err));
    OCL_CHECK(err, 
              ptr_idp = (int*)q.enqueueMapBuffer(id_pair_buffer, CL_TRUE, CL_MAP_READ, 0, id_pair_size, NULL, NULL, &err));

    // Randomize data (int for now)
    // TODO: replace randomization with reading binary vectors from a file
    for (int i = 0; i < (int) ref_buf_size; i++) {
        ptr_ref[i] = rand() % RAND_MAX;
    }
    for (int i = 0; i < (int) cmp_buf_size; i++) {
        ptr_cmp[i] = rand() % RAND_MAX;
    }


    // Copy buffers to kernel memory space
    OCL_CHECK(err, err = q.enqueueMigrateMemObjects({vec_ref_buffer, cmp_ref_buffer}, 0 /* 0 means from host*/));

    // Configure threshold BRAM
    configure_threshold_ram();

    // Launch the Kernel
    OCL_CHECK(err, err = q.enqueueTask(tanimoto_krnl));

    // Cpoy ID pair to host memory space
    OCL_CHECK(err, q.enqueueMigrateMemObjects({id_pair_buffer}, CL_MIGRATE_MEM_OBJECT_HOST));

    OCL_CHECK(err, q.finish());

    // Verify the result --> Just check if we are getting data at all for now
    // TODO: enable result verification using local C implementation
/*  int match = 0;
    for (int i = 0; i < DATA_SIZE; i++) {
        int host_result = ptr_ref[i] + ptr_cmp[i];
        if (ptr_idp[i] != host_result) {
            printf(error_message.c_str(), i, host_result, ptr_idp[i]);
            match = 1;
            break;
        }
    } */

    OCL_CHECK(err, err = q.enqueueUnmapMemObject(vec_ref_buffer, ptr_ref));
    OCL_CHECK(err, err = q.enqueueUnmapMemObject(cmp_ref_buffer, ptr_cmp));
    OCL_CHECK(err, err = q.enqueueUnmapMemObject(id_pair_buffer, ptr_idp));
    OCL_CHECK(err, err = q.finish());

    // std::cout << "TEST " << (match ? "FAILED" : "PASSED") << std::endl;
    int match = 0;
    std::cout << "TEST FINISHED!" << std::endl;
    return (match ? EXIT_FAILURE : EXIT_SUCCESS);
}

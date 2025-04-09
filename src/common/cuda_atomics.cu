// cuda_atomics.cu
#include <cuda.h>
#include <cuda_fp16.h>

extern "C" {
    __device__ __half atomicAdd_half(__half* address, __half val) {
        return atomicAdd(address, val);
    }
}

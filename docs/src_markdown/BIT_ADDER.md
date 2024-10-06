
### Bit Adder

The bit adder module is a fully combinational adder module, that sums all bits in the input word.

- Parameter:
  - VECTOR_WIDTH: default is 6, since the number of inputs on a Xilinx/AMD FPGA LUT is 6. This way minimal resources are used.
- Input:
  - i_Vector
- Output:
  - o_Sum

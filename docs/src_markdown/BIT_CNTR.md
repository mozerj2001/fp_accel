
### Bit Counter

This module implements an adder-tree based pipeline that counts the number of bits in the input vector. The 0th level of the pipeline is built from **bit_adder** modules, the outputs of which are the sum of high bits in every six bits of the input vector. Every subsequent pipeline stage is an adder that sums three results from the previous stage. Input words are zero-padded to the width of 3^**PIPELINE_DEPTH***6, which does not influence the output value, but allows for the parametrized instantion of adders.

- Parameters:
  - VECTOR_WIDTH: width of the input word.
  - GRANULE_WIDTH: width of the first stage **bit_adder**s, advised to be as wide as LUT inputs on the target platform (6).
- Input:
  - i_Vector
- Output:
  - o_Sum

#### Block diagram

![bit_counter](docs/images/bit_counter.png)

#### Wave example

VECTOR_WIDTH is 8, therefore the pipeline depth is 1.

![Wave_bit_counter](docs/images/wave_bit_cntr.png)
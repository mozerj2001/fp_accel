
### Bit Counter Wrapper

Since a single vector takes up two clock cycles, the result of two cycles of **bit_cntr.o_Sum** need to be added to get the binary weight of that vector. **bit_cntr_wrapper** contains an accumulator register, as well as shiftregisters for delaying the valid signal according to the **bit_cntr** pipeline depth. An separate output signal is used to indicate that a non-intermediary result can be read from the accumulator register.

- Parameters
  - VECTOR_WIDTH
  - GRANULE_WIDTH: see **bit_cntr**
  - OUTPUT_WIDTH
- Input
  - i_Vector
  - i_Valid
  - i_LastWordOfVector: for future compatibility with input vectors that are wider that twice the bus width.
- Output
  - o_Sum
  - o_SumValid: delayed i_Valid.
  - o_SumNew

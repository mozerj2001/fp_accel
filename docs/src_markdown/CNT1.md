
### CNT1

Wrapper encapsulating vector weight counting logic. Valid and other control signals are delayed by the pipeline depth of the instantiated **bit_cntr** module. Input words are counted to determine when the last word of a vector has been received, so that the corresponding calculated weight can be emitted after delaying the input data appropriately.

TODO: Some of these shiftregisters are duplicated in **bit_cntr_wrapper**. These two modules can be merged.

- Parameters
  - VECTOR_WIDTH
  - BUS_WIDTH
  - SUB_VECTOR_NO: how many bus cycles transfer a single fingerprint.
  - GRANULE_WIDTH: see **bit_adder**.
- Input
  - i_Vector
  - i_Valid
- Output
  - o_SubVector: delayed input vector.
  - o_Valid
  - o_Cnt: Sum output.
  - o_CntNew: Output on o_Cnt contains valid data.

#### Block diagram

![cnt1_block](docs/images/cnt1.png)

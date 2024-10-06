
### Comparator

The comparator module uses a block RAM instance to determine whether the Tanimoto dissimilarity index is over or under a certain threshold, without actually calculating the index. Division is avoided, by pre-loading potential division results to **u_result_ram**, which is indexed by the binary weight of the A&B vector. The output of the RAM is then compared against the sum of the binary weights of vectors A and B. When the sum of the weights is greater than the threshold read from the RAM, the output of the module is high.

**u_result_ram** can be configured through a standard BRAM interface.

- Parameters
  - VECTOR_WIDTH
- Input
  - i_CntA, i_CntB, i_CntC: vector weights, where C = A & B.
  - i_Valid
  - i_BRAM_*: BRAM control signals.
- Output
  - o_Dout: 1 - over threshold, 0 - under threshold
  - o_Valid

#### Block diagram

![comparator_block](docs/images/top_cmp.png)

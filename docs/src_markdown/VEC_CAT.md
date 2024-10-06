
### Vector concatenator

Fingerprints are stored continuously in RAM, regardless of their width. Therefore input vectors that are received on AXI Stream, need to be separated and zero-padded before they are fed to the accelerator. **vec_cat** implements this with an internal shiftregister and additional multiplexer logic. Vectors are read from the bus and shifted into the shiftregister, from where their MSB is selected by an index counter. The selected range is determined by a state machine (either the full BUS_WIDTH is selected, or the result is zero-padded), the selected vector portion is written to the output of the module. In case the shiftregister would overflow in the next bus cycle, the read signal is deasserted and the index register's value is reduced by BUS_WIDTH, since the next vector is already loaded into the shiftregister. Reading then continues in the next cycle.
Each vector is assigned an ID, which is their position in the dataset. This is achieved by a counter that increments every time the last word of the current vector is read from the bus.

- Parameters
  - BUS_WIDTH
  - VECTOR_WIDTH
  - VEC_ID_WIDTH: depends on how many vectors are part of the current dataset.
- Input (interface behavior is similar to AXI Stream)
  - i_Vector
  - i_Valid
- Output
  - o_Vector
  - o_Valid
  - o_VecID
  - o_Read

#### Block diagram

![vec_cat_block](docs/images/vector_concatenator_mux.png)

#### Input -> Output

![vec_cat_io](docs/images/vector_concatenator_mem.png)

#### Shiftregister multiplexing behavior

![vec_cat_shr](docs/images/vector_concatenator_shr.png)

#### Waveform for VECTOR_WIDTH=10, BUS_WIDTH=8

When o_Read is set to 0 by the vector concatenator, the internal shiftregister would overflow and some of the next to-be-emitted vector would be lost. How many times the bus is stopped, depends on the VECTOR_WIDTH/BUS_WIDTH ratio, as well as the size of the internal shiftregister. (The bus is usually stopped at a regular interval, the current example is werd due to the small vector size.)

![vec_cat_wave](docs/images/wave_vec_cat.png)

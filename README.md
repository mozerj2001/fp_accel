*2023 BME MIT - Hardware Accelerator for calculating Tanimoto distance*

**MODULES:**

**[1] bit_cntr:** A pipelined module that outputs the number of '1' bits in its input vector. 
			To save resources, all adders in the modules have three inputs instead of two. 
			This means the input vector needs to be padded, so that it has 3^N times three granules of the configured size. 
			Summing the bits of each granule, then summing the results in groups of three is the first stage of the pipeline. 
			In all other stages, the results of the previous stage are wired to the input of a three-input adder. 
			The last stage of the pipeline drives i_Sum.

	*in*: i_Vector - input data
	*out*: o_Sum - number of '1' bits in the input data vector



**[2] bit_adder:** Counts '1's in the input vector. Only contains comb logic, uses blocking statements, 
			therefore propagation times are important to consider at instantiation.

	*in*: i_Vector - input data
	*out*: o_Sum - number of '1' bits in the input data vector
	
**[3] bit_cntr_wrapper:** Wrapper module instantiating the bit_cntr module, with an accumulator register in case
					the input vector is multiple times as wide as the bus width.
	
	*in*: i_Vector - input data
		  i_Valid - current input is valid and should count towards the sum stored in the accumulator
		  i_LastWordOfVector - current i_Vector is the last in a wider input vector transferred as
							a sequence of i_Vectors
	*out*: o_Sum - value stored in the acccumulator
		   o_SumValid - a valid calculation is currently ongoing
		   o_SumNew - current o_Sum value is the complete sum of a multiple i_Vector long vector
		   
		   
**[4] lut_ram:** LUT RAM module for extreme width and very shallow depth

**[5] lut_shr:** LUT shiftregister module for storing vectors in addressable shiftregisters

**[6] pre_stage_unit:** Instantiates a bit counter, outputs the input vector's CNT value.
					Delays the input vector with a shiftregister so that the vector appears
					on the output parallel to its CNT value.
					
	*in*: i_Vector - input data
		  i_Valid - current input is valid and should be fed into the bit_cntr_wrapper module
	*out*: o_SubVector - one of the input vectors corresponding to the current o_Cnt output, changes
						every clock cycle
		   o_Cnt - number of '1's in the input vector series (currently being emitted on o_SubVector
		   o_CntNew - first sub vector of new CNT on o_Cnt can be read from o_SubVector

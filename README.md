*2023 BME MIT - Hardware Accelerator for calculating Tanimoto distance*

**MODULES:**
[1] bit_cntr: A pipelined module that outputs the number of '1' bits in its input vector. 
			To save resources, all adders in the modules have three inputs instead of two. 
			This means the input vector needs to be padded, so that it has 3^N times three granules of the configured size. 
			Summing the bits of each granule, then summing the results in groups of three is the first stage of the pipeline. 
			In all other stages, the results of the previous stage are wired to the input of a three-input adder. 
			The last stage of the pipeline drives i_Sum.

	*in*: i_Vector - input data
	*out*: o_Sum - number of '1' bits in the input data vector



[2] bit_adder: Counts '1's in the input vector. Only contains comb logic, uses blocking statements, 
			therefore propagation times are important to consider at instantiation.

	*in*: i_Vector - input data
	*out*: o_Sum - number of '1' bits in the input data vector
	
[3] bit_cntr_wrapper: Wrapper module instantiating the bit_cntr module, with an accumulator register in case
					the input vector is multiple times as wide as the bus width.
	
	*in*: i_Vector - input data
		  i_Valid - current input is valid and should count towards the sum stored in the accumulator
		  i_LastWordOfVector - current i_Vector is the last in a wider input vector transferred as
							a sequence of i_Vectors
	*out*: o_Sum - value stored in the acccumulator
		   o_SumValid - a valid calculation is currently ongoing
		   o_SumNew - current o_Sum value is the complete sum of a multiple i_Vector long vector
		   
[5] lut_ram: LUT RAM module for extreme width and very shallow depth
[6] lut_shr: LUT shiftregister module for storing vectors in addressable shiftregisters

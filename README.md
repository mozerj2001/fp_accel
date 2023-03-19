*2023 BME MIT - Hardware Accelerator for calculating Tanimoto distance*

**MODULES:**
[1] bit_cntr: A pipelined module that outputs the number of '1' bits in its input vector. To save resources, all adders in the modules have three inputs instead of two. This means the input vector needs to be padded, so that it has 3^N times three granules of the configured size. Summing the bits of each granule, then summing the results in groups of three is the first stage of the pipeline. In all other stages, the results of the previous stage are wired to the input of a three-input adder. The last stage of the pipeline drives i_Sum.

	*in*: i_Vector - input data
	*out*: o_Sum - number of '1' bits in the input data vector



[2] bit_adder: Counts '1's in the input vector. Only contains comb logic, uses blocking statements, therefore propagation times are imoortant to consider at instantiation.

	*in*: i_Vector - input data
	*out*: o_Sum - number of '1' bits in the input data vector

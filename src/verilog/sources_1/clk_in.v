`ifndef CLK_IN
`define CLK_IN

// Purpose: Accept input from two differential input pins and
// route it to the design as a clock signal.

// AMD DOCS: UG974

module clk_in #()(
    input wire clk_p,
    input wire clk_n,
    output wire clk
);

wire O;

/////////////////////////////////////////////////////////////////////////////////////
// IBUFDS: Differential Input Buffer
//         UltraScale
// Xilinx HDL Language Template, version 2023.2

IBUFDS IBUFDS_inst (
   .O(O),   // 1-bit output: Buffer output
   .I(clk_p),   // 1-bit input: Diff_p buffer input (connect directly to top-level port)
   .IB(clk_n)  // 1-bit input: Diff_n buffer input (connect directly to top-level port)
);

// End of IBUFDS_inst instantiation


/////////////////////////////////////////////////////////////////////////////////////
// BUFG: General Clock Buffer
//       UltraScale
// Xilinx HDL Language Template, version 2023.2

BUFG BUFG_inst (
   .O(clk), // 1-bit output: Clock output.
   .I(O)  // 1-bit input: Clock input.
);

// End of BUFG_inst instantiation

endmodule // clk_in

`endif // CLK_IN

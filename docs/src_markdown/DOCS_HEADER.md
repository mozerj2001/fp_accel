
# Accelerator for calculating Tanimoto index

2023-24 József Mózer @ BME MIT
Feel free to reach out to me on GitHub, or send an email to jozsef.mozer@edu.bme.hu.

## Table of contents

- [Introduction](#introduction)
- [Project structure](#project-structure)
- [RTL Kernel](#rtl-kernel)
  - [Bit Adder](#bit-adder)
  - [Bit Counter](#bit-counter)
  - [Bit Counter Wrapper](#bit-counter-wrapper)
  - [CNT1](#cnt1)
  - [Comparator](#comparator)
  - [Vector Concatenator](#vector-concatenator)
  - [Top Level](#top-level)

## Introduction

The Tanimoto index, also known as Tanimoto dissimilarity, is a metric used in chemical informatics to [determine the similarity of two molecules](https://jcheminf.biomedcentral.com/articles/10.1186/s13321-015-0069-3). Specific attributes of molecules are mapped to a binary vector or a 2D bitmap, often reffered to as molecular fingerprints. The Tanimoto index for two such fingerprints A and B is defined as the Jaccard index of the two sets, with bits in certain positions indicating the presence (1) or absence (0) of a set member. Therefore tan(A, B) = |A & B| / (|A| + |B|), where |A| is the binary weight of bitmap A.

Calculating this metric in software is slow, due to the slowness of division, and the difficulty of handling large binary vectors with arbitrary widths (e. g. 920, or 320x320). The goal is to create an efficient Tanimoto index calculator in Verilog and package it with the AMD Vitis RTL kernel flow.

## Project structure

The implemented hardware is consists of three parts:

### RTL kernel

The RTL kernel can be found in `tanimoto_rtl/verilog/sources_1/`. It is built of a pipeline, that's depth is a synthesis parameter called SHR_DEPTH. The kernel reads vectors form an AXI-Stream port, the width of which can be between 50% and 100% of the fingerprint width. The first SHR_DEPTH vectors will be compared aginst the vectors arriving after. Binary weight calculation is done by adder trees, division is avoided by pre-loading BRAM blocks with potential division results. Vectors' index, thats Tanimoto dissimilarity index is over the configured threshold are returned through a hierarchic elastic memory buffer. They are output concatenated through an AXI Stream port.

### HLS interface

A DMA-like module written in Vitis HLS, that bridges the AXI-4 ports of the processor subsystem and the AXI Stream interfaces of the RTL kernel.

### Processor subsystem

A PS, containing an AXI interface for burst transactions to and from the accelerator kernel and an AXI-BRAM controller for configuring the BRAMs with division results.

![system](docs/images/acceleration_platform.png)

## Build process

The build process revolves around the v++ linker. First, the RTL kernel source files are backaged into a single IP block with `make rtl_ip`. Then it is packaged with `make rtl_xo`. Afterwards, the HLS interface is also packaged with `make hls_xo`, and the platform is created with `make platform`. (This requires a prior PetaLinux and Vitis environment setup. For these steps, please refer to the [official documentation](https://github.com/Xilinx/Vitis-Tutorials/blob/2023.2/Vitis_Platform_Creation/Design_Tutorials/02-Edge-AI-ZCU104/step2.md) by AMD. NOTE: Switch zcu104-revc to zcu106-reva or your own platform.) Finally the Vitis linker can be launched to create the final acceleration platform with `make xclbin`.

To see all Makefile options, run `make help`.

![build](docs/images/build_flow.png)

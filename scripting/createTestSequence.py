import os

# Python script to read vectors from a TXT file, concatenate them
# in accordance with BUS_WIDTH_Q, then write them to a Verilog
# file that can be included directly in the testbench.

# NOTE: DUE TO THE HEXA STRING FORMAT, EVERYTHING HAS TO BE DIVISIBLE BY 4!!!
# CURRENT: 128 bit vectors on a 96 bit bus...

BUS_WIDTH_Q = 24;               # internal bus width divided by 4, to which vectors will be concatenated
CLK_STR = "#CLK_PERIOD;\n"      # wait 1 clk period (Verilog)
ASSIGN_STR = "f_din <= "        # assign to fifo input


# Read vectors from input txt (one vector per line) and concatenate them
# so that 
def processVectorTxt(fname: str):
    linesCatList = list()
    linesRdList = list()
    i = 0
 
    # get vectors and put them in a list as strings
    with open(fname, "r") as fprd:
        lines_rd = fprd.read()
    linesRdList = lines_rd.split('\n')

    # calc no of iterations until concatenation reset   (catSlice and repNo are assumed to be integers)
    vecWidth = len(linesRdList[0])
    catSlice = vecWidth-BUS_WIDTH_Q

    # concatenate vectors
    slice = 0
    while i < len(linesRdList)-1:     # -1 needed, the generator prints an extra line to the end of the file
        if slice == 0:
            linesCatList.append(linesRdList[i][0:BUS_WIDTH_Q] + '\n')
            slice = catSlice
        else:
            linesCatList.append(linesRdList[i][vecWidth-slice:vecWidth] + linesRdList[i+1][0:BUS_WIDTH_Q-slice] + '\n')
            slice = slice + catSlice
            i = i + 1
            if slice == vecWidth:
                slice = 0

    if len(linesCatList[-1]) < BUS_WIDTH_Q: del linesCatList[-1]

    return linesCatList


def writeTest(vec_list: list, fname: str):
    with open(fname, "w") as fpwr:
        fpwr.writelines(vec_list)
            


# BODY
if __name__ == "__main__":
    catVectors = processVectorTxt("../c_implementation/ref_vec.txt")
    writeTest(catVectors, "../project_1.srcs/sources_1/new/test_vectors.dat")
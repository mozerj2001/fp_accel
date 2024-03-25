import os

# Python script to read vectors from a TXT file, concatenate them
# in accordance with BUS_WIDTH_Q, then write them to a Verilog
# file that can be included directly in the testbench.

# NOTE: DUE TO THE HEXA STRING FORMAT, EVERYTHING HAS TO BE DIVISIBLE BY 4!!!
# CURRENT: 920 bit vectors on a 512 bit bus...

BUS_WIDTH_Q = 128;              # internal bus width divided by 4, to which vectors will be concatenated


# Read vectors from input txt (one vector per line) and concatenate them
# so that they are continuous. What this will really do is put all vectors
# one after another into a string, then split the string into BUS_WIDTH_Q
# long pieces.
def processVectorTxt(ref_fname: str, cmp_fname: str):
    linesRdList = list()
 
    # get vectors and put them in a list as strings
    with open(ref_fname, "r") as f:
        linesRd = f.read()
    linesRdList = linesRd.split('\n')

    with open(cmp_fname, "r") as f:
        linesRd = f.read()
    linesRdList.extend(linesRd.split('\n'))


    rawStr = "".join(linesRdList)

    linesWrList = [ (rawStr[i:i+BUS_WIDTH_Q] + "\n") for i in range(0, len(rawStr), BUS_WIDTH_Q) ]

    return linesWrList


def writeTest(vec_list: list, fname: str):
    with open(fname, "w") as fpwr:
        fpwr.writelines(vec_list)
            


# BODY
if __name__ == "__main__":
    catVectors = processVectorTxt("../c_implementation/ref_vec.txt", "../c_implementation/cmp_vec.txt")
    writeTest(catVectors, "../fp_accel.srcs/sources_1/new/test_vectors.dat")

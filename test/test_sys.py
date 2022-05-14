from cmath import exp
import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles, with_timeout, ReadOnly
import random
from cocotb.binary import BinaryValue
import numpy as np


async def write_ram(dut, address, value):
    await RisingEdge(dut.clk)              # Synchronise to the read clock
    dut.we = 1
    dut.addr_w = address
    dut.data_in = value
    await RisingEdge(dut.clk)              # Wait 1 clock cycle
    dut.we = 0                        # Disable write


async def read_ram(dut, address):
    await RisingEdge(dut.clk)               # Synchronise to the read clock
    dut.value.addr_r = address                   # Drive the value onto the signal
    await RisingEdge(dut.clk)               # Wait for 1 clock cycle


async def RST(dut):
    dut.reset <= 1
    await ClockCycles(dut.clk, 1)
    dut.reset <= 0
    # await ClockCycles(dut.clk, 1)

async def write_i(dut,data):
    dut.input_i = BinaryValue(data)
    await RisingEdge(dut.clk)

async def write_d(dut,data):
    dut.data = BinaryValue(data)
    await RisingEdge(dut.clk)



async def print_sys_out(sa):
    print('>', sa.count.value.integer)
    # print('>', sa.result_o.value)
    # if sa.out.value.is_resolvable:
    #     result = sa.out.value
    #     print(">",result, result.buff)

async def print_pe_out(out):
    if out.value.is_resolvable:
        result = out.value.integer
        print(out.value.integer," - ",end="")
        return int(result)


@cocotb.test()
async def test_sys(dut):
    """Test reading data from RAM"""


    clock = Clock(dut.clk, 10, units="us")
    cocotb.fork(clock.start())
    # np.random.randint(255, size=(3, 3))
    await RST(dut)
    W = [[1, 4, 5],
         [5, 8, 9],
         [6, 7, 11]]

    Wt = [[1, 5, 6],
         [4, 8, 7],
         [5, 9, 11]]

    I = [[1, 5, 12],
         [5, 9, 0],
         [6, 11, 19]]
    # W = np.random.randint(128, size=(3,3),dtype=np.dtype(int) )
    # Wt = W.transpose().tolist();
    # I = np.random.randint(128, size=(3,3),dtype=np.dtype(int) ).tolist()


    expected = np.matmul(W,I)
    '''We need to transpose the matrix as current processing arragement'''
    # It = [[1, 5, 6],
    #      [5, 9 , 11],
    #      [12, 0, 19]]

    w_data = Wt[1][0] << 24 | Wt[0][2] << 16 | Wt[0][1] << 8 | Wt[0][0]
    dut.data = BinaryValue(w_data)
    await RisingEdge(dut.clk)
    w_data = Wt[2][1] << 24 | Wt[2][0] << 16 | Wt[1][2] << 8 | Wt[1][1]
    dut.data = BinaryValue(w_data)
    await RisingEdge(dut.clk)
    w_data = Wt[2][2]
    dut.data = BinaryValue(w_data)
    await RisingEdge(dut.clk)


    # w_data = It[0][0]
    # await write_i(dut, w_data)
    # w_data = It[1][0] << 8 | It[0][1] 
    # await write_i(dut, w_data)
    # w_data = It[2][0] << 16 | It[1][1] << 8 | It[0][2]
    # await write_i(dut, w_data)
    # w_data = It[2][1] << 16 | It[1][2] << 8
    # await write_i(dut, w_data)
    # w_data = It[2][2] << 16 
    # await write_i(dut, w_data)


    # grab the indices of the output array to  accumulate 

    # from the streaming input it needs 3x3 matrix needs 8 clock cicles to finish the complete multiplication
    # todo: loop it
    # get the formula from the paper 
    w_data = I[0][0]
    await write_i(dut, w_data)
    w_data = I[1][0] << 8 | I[0][1] 
    await write_i(dut, w_data)
    w_data = I[2][0] << 16 | I[1][1] << 8 | I[0][2]
    await write_i(dut, w_data)
    w_data = I[2][1] << 16 | I[1][2] << 8
    await write_i(dut, w_data)

    observed = np.zeros((3,3))
    
    
    # await print_sys_out(dut.sa)
    # observed[0][0] = await print_pe_out(dut.sa.o_1)
    # print("\n 1---", dut.result_o)
    w_data = I[2][2] << 16 
    await write_i(dut, w_data)
    

    mask_0= (1<<10)-1
    mask_1 = mask_0 << 10
    mask_2 = mask_0 << 20
    masks = [mask_0,mask_1,mask_2]
    index = 0
    for i in range(20):
        ops = dut.ops.value.integer
        print(ops)
        if ops > 6:
            value = dut.out.value.integer
            if value > 0:
                print('------------',value)
                for i,mask in enumerate(masks):
                    observed[index][i] = int((value & mask) >> (i*10))
                index = index + 1  


        await ClockCycles(dut.clk, 1)

    print(observed)
    # await print_sys_out(dut.sa)
    # observed[0][1] = await print_pe_out(dut.sa.o_1)
    # observed[1][0] = await print_pe_out(dut.sa.o_2)
    # await ClockCycles(dut.clk, 1)
    # print("\n 2---", dut.result_o)

    # await print_sys_out(dut.sa)
    # observed[0][2] = await print_pe_out(dut.sa.o_1)
    # observed[1][1] = await print_pe_out(dut.sa.o_2)
    # observed[2][0] = await print_pe_out(dut.sa.o_3)
    # await ClockCycles(dut.clk, 1)
    # print("\n 3---", dut.result_o)

    # await print_sys_out(dut.sa)
    # observed[1][2] = await print_pe_out(dut.sa.o_2)
    # observed[2][1] = await print_pe_out(dut.sa.o_3)
    # await ClockCycles(dut.clk, 1)
    # print("\n 4---", dut.result_o)

    # await print_sys_out(dut.sa)
    # observed[2][2] = await print_pe_out(dut.sa.o_3)
    # await ClockCycles(dut.clk, 1)
    # print("\n 5---", dut.result_o)

    # print(observed)
    print(expected)
    for i in range(3):
        for j in range(3):
            assert(observed[i][j] == expected[i][j])

    # indices = [
    #     [0,0],
    #     [1,0],[0,1]
    #     [2,0],[1,1],[0,2]
    #     [2,1],[1,2]
    #     [3,3]
    # ]
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


async def write_i(dut, data):
    dut.input_i = BinaryValue(data)
    await RisingEdge(dut.clk)


async def write_d(dut, data):
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
        # print(out.value.integer)
        return int(result)


@cocotb.test()
async def test_sys(dut):
    """Test reading data from RAM"""

    for i in range(200):
        clock = Clock(dut.clk, 10, units="us")
        cocotb.fork(clock.start())
        # np.random.randint(255, size=(3, 3))
        await RST(dut)

        ''' generate random input matrices bit len 7 for the moment , we need to transpose the weights before start '''
        # W = np.random.randint(8, size=(3,3),dtype=np.dtype(int) )
        # I = np.random.randint(8, size=(3,3),dtype=np.dtype(int) ).tolist()
        W = np.random.choice(list(range(1, 128)), (3, 3))
        # W = W.astype(int)
        I = np.random.choice(list(range(1, 128)), (3, 3))
        # I = I.astype(int)
        '''We need to transpose the matrix as current processing arragement'''
        Wt = np.array(W).transpose().tolist()
        # Wt = Wt.astype(int)

        # print(W)
        # print(I)

        expected = np.matmul(W, I)
        '''
        1. stage load waigths
        '''
        w_data = Wt[1][0] << 24 | Wt[0][2] << 16 | Wt[0][1] << 8 | Wt[0][0]
        dut.data = BinaryValue(w_data)
        await RisingEdge(dut.clk)
        w_data = Wt[2][1] << 24 | Wt[2][0] << 16 | Wt[1][2] << 8 | Wt[1][1]
        dut.data = BinaryValue(w_data)
        await RisingEdge(dut.clk)
        w_data = Wt[2][2]
        dut.data = BinaryValue(w_data)
        await RisingEdge(dut.clk)

        '''
        2. stage run: stream the input matrix in diagonal shape: rustic mode for now :P 
        '''
        w_data = int(I[0][0])
        await write_i(dut, w_data)
        w_data = int(I[1][0]) << 8 | int(I[0][1])
        await write_i(dut, w_data)
        w_data = int(I[2][0]) << 16 | int(I[1][1]) << 8 | int(I[0][2])
        await write_i(dut, w_data)
        w_data = int(I[2][1]) << 16 | int(I[1][2]) << 8
        await write_i(dut, w_data)
        w_data = int(I[2][2]) << 16
        await write_i(dut, w_data)

        '''
        3. stage stop: collect data 
        '''
        observed = np.zeros((3, 3))
        mask_0 = (1 << 16)-1
        mask_1 = mask_0 << 16
        masks = [mask_0, mask_1]
        values = []
        for i in range(12):
            ops = dut.ops.value.integer
            if ops > 6:
                # value = dut.out.value.integer
                value = await print_pe_out(dut.out)
                if value is not None and value > 0:
                    for i, mask in enumerate(masks):
                        ob = int((value & mask) >> (i*16))
                        values.append(ob)

            await ClockCycles(dut.clk, 1)

        if len(values) < 9:
            print("failed----------------------------------->")
            print(W)
            print(I)
            assert(0)
        else:
            for k in range(9):
                i = int(k / 3)
                j = k % 3
                observed[i][j] = values[k]

            print(observed)
            print(expected)
            for i in range(3):
                for j in range(3):
                    assert(observed[i][j] == expected[i][j])

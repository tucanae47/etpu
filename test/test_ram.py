"""
test caravel wishbone
"""

from struct import pack
import cocotb
from cocotb.clock import Clock
from cocotb.binary import BinaryValue
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles
from cocotbext.wishbone.driver import WishboneMaster, WBOp
from cocotbext.wishbone.monitor import WishboneSlave
import random
import numpy as np

# from J Pallent: 
# https://github.com/thejpster/zube/blob/9299f0be074e2e30f670fd87dec2db9c495020db/test/test_zube.py
async def test_wb_set(caravel_bus, addr, value):
    """
    Test putting values into the given wishbone address.
    """
    await caravel_bus.send_cycle([WBOp(addr, value)])

async def test_wb_get(caravel_bus, addr):
    """
    Test getting values from the given wishbone address.
    """
    res_list = await caravel_bus.send_cycle([WBOp(addr)])
    rvalues = [entry.datrd for entry in res_list]
    return rvalues[0]

async def reset(dut):
    dut.caravel_wb_rst_i = 1
    dut.caravel_wb_dat_i = 0
    await ClockCycles(dut.caravel_wb_clk_i, 1)
    dut.caravel_wb_rst_i = 0
    await ClockCycles(dut.caravel_wb_clk_i, 1)

async def reset2(dut):
    dut.caravel_wb_rst2_i = 1
    await ClockCycles(dut.caravel_wb_clk_i, 4)
    dut.caravel_wb_rst2_i = 0
    await ClockCycles(dut.caravel_wb_clk_i, 4)

def diagonal(arr, n):
    ans = [[] for i in range(n*2 - 1)]
    for i in range(n):
        for j in range(n):
            ans[i + j].append(arr[i][j])
    vecna = []
    for i in range(len(ans)):
        for j in range(len(ans[i])):
            vecna.append(ans[i][j])
    return vecna

@cocotb.test()
async def test_etpu_wb(dut):
    """
    Run all the tests
    """
    clock = Clock(dut.caravel_wb_clk_i, 10, units="us")
    
    cocotb.fork(clock.start())

    caravel_bus_signals_dict = {
        "cyc"   :   "caravel_wb_cyc_i",
        "stb"   :   "caravel_wb_stb_i",
        "we"    :   "caravel_wb_we_i",
        "adr"   :   "caravel_wb_adr_i",
        "datwr" :   "caravel_wb_dat_i",
        "datrd" :   "caravel_wb_dat_o",
        "ack"   :   "caravel_wb_ack_o"
    }

    caravel_bus = WishboneMaster(dut, "", dut.caravel_wb_clk_i, width=32, timeout=10, signals_dict=caravel_bus_signals_dict)
    
    for k in range(1):
        await reset(dut)
        # await reset2(dut)

        W = [[1, 4, 5],
             [5, 8, 9],
             [6, 7, 11]]

        Wt = [[1, 5, 6],
             [4, 8, 7],
             [5, 9, 11]]

        I = [[1, 5, 12],
             [5, 9, 0],
             [6, 11, 19]]

        # W = np.random.choice(list(range(1, 128)), (3, 3))
        # W = W.astype(int)
        # I = np.random.choice(list(range(1, 128)), (3, 3))
        # I = I.astype(int)
        '''We need to transpose the matrix as current processing arragement'''
        # Wt = np.array(W).transpose().tolist()
        
        # expected = np.matmul(np.array(Wt), np.array(I))
        expected = np.matmul(W, I)
        print(expected)

        # default base addr
        base_addr = 0x3000_0000
        # base_addr = 0x300_0000
        w_data = 15

        Wtdiag = []
        # Wtdiag = diagonal(Wt,3)
        for i in range(3):
            for j in range(3):
                Wtdiag.append(Wt[i][j])
        # print(Wtdiag)
        for i,w in enumerate(Wtdiag):
            print(i,w)
            await test_wb_set(caravel_bus, base_addr + i, w)

        # TODO:? need to send another value to the bus, dunno why yet 
        # await test_wb_set(caravel_bus, base_addr, 0)

        await ClockCycles(dut.caravel_wb_clk_i, 2)
       
       
        w_data = int(I[0][0])
        await test_wb_set(caravel_bus, base_addr, w_data)
        w_data = int(I[1][0]) << 8 | int(I[0][1])
        await test_wb_set(caravel_bus, base_addr, w_data)
        w_data = int(I[2][0]) << 16 | int(I[1][1]) << 8 | int(I[0][2])
        await test_wb_set(caravel_bus, base_addr, w_data)
        w_data = int(I[2][1]) << 16 | int(I[1][2]) << 8
        await test_wb_set(caravel_bus, base_addr, w_data)
        w_data = int(I[2][2]) << 16
        await test_wb_set(caravel_bus, base_addr, w_data)


        for i in range(28, 48):
            value = await test_wb_get(caravel_bus, base_addr + i)
            print(value)
        # await test_wb_set(caravel_bus, base_addr, 0)
        # await test_wb_set(caravel_bus, base_addr, 0)
        # await test_wb_set(caravel_bus, base_addr, 0)
        # await ClockCycles(dut.caravel_wb_clk_i, 20)


        # for i in range(10):
        #     value = await test_wb_get(caravel_bus, base_addr+ i )
        #     print(value)
        #     # print(int(value))





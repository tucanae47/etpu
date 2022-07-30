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
    
    for k in range(200):
        await reset(dut)
        await reset2(dut)

        # W = [[1, 4, 5],
        #      [5, 8, 9],
        #      [6, 7, 11]]

        # Wt = [[1, 5, 6],
        #      [4, 8, 7],
        #      [5, 9, 11]]

        # I = [[1, 5, 12],
        #      [5, 9, 0],
        #      [6, 11, 19]]

        W = np.random.choice(list(range(1, 128)), (3, 3))
        # W = W.astype(int)
        I = np.random.choice(list(range(1, 128)), (3, 3))
        # I = I.astype(int)
        '''We need to transpose the matrix as current processing arragement'''
        Wt = np.array(W).transpose().tolist()
        
        # expected = np.matmul(np.array(Wt), np.array(I))
        expected = np.matmul(W, I)

        # default base addr
        base_addr = 0x3000_0000
        w_data = Wt[1][0] << 24 | Wt[0][2] << 16 | Wt[0][1] << 8 | Wt[0][0]
        await test_wb_set(caravel_bus, base_addr, w_data)
        # data = await test_wb_get(caravel_bus, base_addr)
        w_data = Wt[2][1] << 24 | Wt[2][0] << 16 | Wt[1][2] << 8 | Wt[1][1]
        await test_wb_set(caravel_bus, base_addr, w_data)
        # data = await test_wb_get(caravel_bus, base_addr)
        w_data = Wt[2][2]
        await test_wb_set(caravel_bus, base_addr, w_data)

        # TODO:? need to send another value to the bus, dunno why yet 
        await test_wb_set(caravel_bus, base_addr, 0)


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

        await ClockCycles(dut.caravel_wb_clk_i, 20)
        # for i in range(4):
        #    await test_wb_get(caravel_bus, base_addr)

        observed = np.zeros((3, 3))
        print(expected)
        mask_0 = (1 << 16)-1
        mask_1 = mask_0 << 16
        masks = [mask_0, mask_1]
        # print(int(value),hex(value))
        all = []
        for i in range(10):
            value = await test_wb_get(caravel_bus, base_addr)
            os = []
            for i, mask in enumerate(masks):
                ob = int((value & mask) >> (i*16))
                os.append(ob)
            all.extend(os)

        DIM = 3
        skips,grabs = [], []
        for j in range(DIM,0,-1):
            skip = j -1 
            grab = DIM - skip
            skips.append(skip)
            grabs.append(grab)
        for j in range(1,DIM):
            skip = j 
            grab = DIM - skip
            skips.append(skip)
            grabs.append(grab)

        head = 2
        observed = []
        for i in range(DIM):
            for i in range(grabs[i]):
                observed.append(all[head])
                head += 1
            head += skips[i]

        for i in range(DIM, len(grabs)):
            head += skips[i]
            for i in range(grabs[i]):
                observed.append(all[head])
                head += 1

        expected = diagonal(expected,DIM)
        for k in range(9):
            assert(expected[k] == observed[k])





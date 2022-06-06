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
    dut.rst = 1
    dut.wb_dat_i = 0
    await ClockCycles(dut.clock, 1)
    dut.rst = 0
    await ClockCycles(dut.clock, 1)

@cocotb.test()
async def test_etpu_wb(dut):
    """
    Run all the tests
    """
    clock = Clock(dut.clock, 10, units="us")
    

    #dut.rambus_wb_ack_i = 1;
    #dut.rambus_wb_dat_i = 0xABCDEFAB;

    cocotb.fork(clock.start())

    caravel_bus_signals_dict = {
        "cyc"   :   "wb_cyc_i",
        "stb"   :   "wb_stb_i",
        "we"    :   "wb_we_i",
        "adr"   :   "wb_adr_i",
        "datwr" :   "wb_dat_i",
        "datrd" :   "wb_dat_o",
        "ack"   :   "wb_ack_o"
    }

    caravel_bus = WishboneMaster(dut, "", dut.clock, width=32, timeout=10, signals_dict=caravel_bus_signals_dict)
    
    # ram_bus     = WishboneRAM    (dut, dut.rambus_wb_clk_o, ram_bus_signals_dict)

    # load a triangle wave into the ram, first 15 words (4 bytes per word, so 60 data points), starting at 10, incremementing by 1 each time

    await reset(dut)

    W = [[1, 4, 5],
         [5, 8, 9],
         [6, 7, 11]]

    Wt = [[1, 5, 6],
         [4, 8, 7],
         [5, 9, 11]]

    I = [[1, 5, 12],
         [5, 9, 0],
         [6, 11, 19]]
    
    # expected = np.matmul(np.array(Wt), np.array(I))
    expected = np.matmul(W, I)
    print(expected)

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
    await test_wb_set(caravel_bus, base_addr, 0)
    # await ClockCycles(dut.clock, 25)

    # # fetch it
    # print(data, "-----------")
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

    await ClockCycles(dut.clock, 25)
    data = await test_wb_get(caravel_bus, base_addr)
    print(data)
    data = await test_wb_get(caravel_bus, base_addr)
    print(data)
    data = await test_wb_get(caravel_bus, base_addr)
    print(data)
    data = await test_wb_get(caravel_bus, base_addr)
    print(data)
    data = await test_wb_get(caravel_bus, base_addr)
    # await ClockCycles(dut.clock, 5)




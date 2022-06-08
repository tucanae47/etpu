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

@cocotb.test()
async def test_etpu_wb(dut):
    """
    Run all the tests
    """
    clock = Clock(dut.caravel_wb_clk_i, 10, units="us")
    

    #dut.rambus_wb_ack_i = 1;
    #dut.rambus_wb_dat_i = 0xABCDEFAB;

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
    
    # ram_bus     = WishboneRAM    (dut, dut.rambus_wb_clk_o, ram_bus_signals_dict)

    for i in range(20):
        await reset(dut)

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

        await ClockCycles(dut.caravel_wb_clk_i, 25)


        observed = np.zeros((3, 3))
        mask_0 = (1 << 16)-1
        mask_1 = mask_0 << 16
        masks = [mask_0, mask_1]
        values = []
        for i in range(5):
            ops = dut.ops.value.integer
            if ops > 6:
                value = await test_wb_get(caravel_bus, base_addr)
                if value is not None :
                    for i, mask in enumerate(masks):
                        ob = int((value & mask) >> (i*16))
                        values.append(ob)
                    
        # the real test :P
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






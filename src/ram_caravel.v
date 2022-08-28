`default_nettype none
`timescale 1ns/1ns

module edu_tpu #(
    parameter   [23:0]  BASE_ADDRESS    = 24'h3000_02,        // base address
    parameter   [15:0]  PERIOD          = 16'd8,                 // default period
    parameter   [7:0]   RAM_END_ADDR  = 8'd0                  // default start address in RAM to read pattern
)(
    // CaravelBus peripheral ports
    input wire          caravel_wb_clk_i,       // clock, runs at system clock
    input wire          caravel_wb_rst_i,       // main system reset
    input wire          caravel_wb_stb_i,       // write strobe
    input wire          caravel_wb_cyc_i,       // cycle
    input wire          caravel_wb_we_i,        // write enable
    input wire  [3:0]   caravel_wb_sel_i,       // write word select
    input wire  [31:0]  caravel_wb_dat_i,       // data in
    input wire  [31:0]  caravel_wb_adr_i,       // address
    output           caravel_wb_ack_o,       // ack
    output   [31:0]  caravel_wb_dat_o       // data out
    
);

    // rename some signals



    dffram_wb ram_wb(
                .wb_clk_i(caravel_wb_clk_i),
                .wb_rst_i(caravel_wb_rst_i),
                .wb_stb_i(caravel_wb_stb_i),
                .wb_cyc_i(caravel_wb_cyc_i),
                .wb_we_i (caravel_wb_we_i ),
                .wb_sel_i(caravel_wb_sel_i),
                .wb_dat_i(caravel_wb_dat_i),
                .wb_adr_i(caravel_wb_adr_i),
                .wb_ack_o(caravel_wb_ack_o),
                .wb_dat_o(caravel_wb_dat_o)
               );


endmodule

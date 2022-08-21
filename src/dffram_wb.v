/*
 * dffram_wb.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2022  Camilo Soto
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

module dffram_wb #(
    parameter   [31:0]  BASE_ADDRESS    = 24'h3000_02,        // base address
	parameter DWIDTH = 24,
	parameter AWIDTH = 9
)(
    // CaravelBus peripheral ports
    input wire          wb_clk_i,       // clock, runs at system clock
    input wire          wb_rst_i,       // main system reset
    input wire          wb_stb_i,       // write strobe
    input wire          wb_cyc_i,       // cycle
    input wire          wb_we_i,        // write enable
    input wire  [3:0]   wb_sel_i,       // write word select
    input wire  [31:0]  wb_dat_i,       // data in
    input wire  [31:0]  wb_adr_i,       // address
    output reg          wb_ack_o,       // ack
    output reg  [31:0]  wb_dat_o       // data out
    
);

    wire clk = wb_clk_i;
    wire reset = wb_rst_i;
	reg [DWIDTH-1:0] r [0:(2**AWIDTH)-1];
	always @(posedge clk) begin
        if(wb_stb_i && wb_cyc_i && wb_we_i && wb_adr_i[31:8] == BASE_ADDRESS) begin
			r[wb_adr_i[7:0]] <= wb_dat_i;
        end
        else if(wb_stb_i && wb_cyc_i && !wb_we_i && wb_adr_i[31:8] == BASE_ADDRESS) begin
            wb_dat_o <= r[wb_adr_i[7:0]];
        end
    end

    // CaravelBus acks
    always @(posedge clk) begin
        if(reset)
            wb_ack_o <= 0;
        else
            // return ack immediately
            wb_ack_o <= (wb_stb_i && wb_adr_i[31:8] == BASE_ADDRESS);
    end


endmodule



  



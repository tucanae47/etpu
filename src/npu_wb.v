/*
 * dffram_wb.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2022  Camilo Soto
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

module npu_wb #(
    parameter   [31:0]  W_ADDRESS    = 24'h3000_00,        // base address
    parameter   [31:0]  S_ADDRESS    = 24'h3000_01,        // base address
    parameter   [31:0]  R_ADDRESS    = 24'h3000_02,        // base address
	parameter DWIDTH = 24,
	parameter AWIDTH = 9
)(
    input          	    clk_npu,
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
    wire rst = wb_rst_i;
	reg [DWIDTH-1:0] w [0:(2**AWIDTH)-1];
    reg [DWIDTH-1:0] out_m [0:(2**AWIDTH)-1];
    reg [7:0] in1,in2,in3;
    reg en;
	always @(posedge clk) begin
        if(wb_stb_i && wb_cyc_i && wb_we_i) begin
            if(wb_adr_i[31:8] == W_ADDRESS)
			    w[wb_adr_i[7:0]] <= wb_dat_i;
            else if(wb_adr_i[31:8] == S_ADDRESS) begin
                in1 <= wb_dat_i[7:0];
                in2 <= wb_dat_i[15:8];
                in3 <= wb_dat_i[23:16];
                en<=1;
            end
        end
        else if(wb_stb_i && wb_cyc_i && !wb_we_i && wb_adr_i[31:8] == R_ADDRESS) begin
            wb_dat_o <= out_m[wb_adr_i[7:0]];
        end
    end

    // CaravelBus acks
    always @(posedge clk) begin
        if(rst)
            wb_ack_o <= 0;
        else
            // return ack immediately on every valid address
            wb_ack_o <= (wb_stb_i && (wb_adr_i[31:8] == W_ADDRESS || wb_adr_i[31:8] == R_ADDRESS || wb_adr_i[31:8] == S_ADDRESS));
    end

    reg [15:0] zero = 15'b0;
    reg [7:0] memout_addr = 8'd0;
    wire [7:0] r_11, r_12, r_13 ;
    wire [15:0] d_11, d_12, d_13 ;
    // 1
    pe pe_11(.clk(clk_npu), .rst(rst), .en(en), .up(zero), .left(in1), .w(w[0*4]), .right(r_11), .down(d_11));
    pe pe_12(.clk(clk_npu), .rst(rst), .en(en), .up(zero), .left(r_11), .w(w[1*4]), .right(r_12), .down(d_12));
    pe pe_13(.clk(clk_npu), .rst(rst), .en(en), .up(zero), .left(r_12), .w(w[2*4]), .right(r_13), .down(d_13));

    //  2
    wire [7:0] r_21, r_22, r_23 ;
    wire [15:0] d_21, d_22, d_23 ;
    pe pe_21(.clk(clk_npu), .rst(rst), .en(en), .up(d_11), .left(in2), .w(w[3*4]), .right(r_21), .down(d_21));
    pe pe_22(.clk(clk_npu), .rst(rst), .en(en), .up(d_12), .left(r_21), .w(w[4*4]), .right(r_22), .down(d_22));
    pe pe_23(.clk(clk_npu), .rst(rst), .en(en), .up(d_13), .left(r_22), .w(w[5*4]), .right(r_23), .down(d_23));
    //  3
    wire [7:0] r_31, r_32, r_33 ;
    wire [15:0] o_1, o_2, o_3 ;
    pe pe_31(.clk(clk_npu), .rst(rst), .en(en), .up(d_21), .left(in3), .w(w[6*4]), .right(r_31), .down(o_1));
    pe pe_32(.clk(clk_npu), .rst(rst), .en(en), .up(d_22), .left(r_31), .w(w[7*4]), .right(r_32), .down(o_2));
    pe pe_33(.clk(clk_npu), .rst(rst), .en(en), .up(d_23), .left(r_32), .w(w[8*4]), .right(r_33), .down(o_3));

    always @(posedge clk_npu)
    begin
        if (en)
        begin
            memout_addr<= memout_addr + 3;
            out_m[memout_addr + 1] <= o_1;
            out_m[memout_addr + 2] <= o_2;
            out_m[memout_addr + 3] <= o_3;
        end
    end

endmodule



  


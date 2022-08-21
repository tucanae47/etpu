`default_nettype none
`timescale 1ns/1ns


module clk_div_n #(
    parameter WIDTH = 7)

  (
    input wire clk,
    input wire rst,
    input wire [WIDTH-1:0] div_num,
    output reg clk_out
  );


  reg [WIDTH-1:0] pos_count;

  always @(posedge clk)
    if (rst)
      pos_count <=0;
    else if (pos_count ==div_num-1)
    begin
      clk_out <= 1;
      pos_count<=0;
    end
    else
    begin
      pos_count<= pos_count +1;
      clk_out<=0;
    end
endmodule

module edu_tpu #(

    parameter   [31:0]  W_ADDRESS    = 24'h3000_00        // base address
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

  wire clk_npu;
  wire clk, rst;
  assign clk 	= caravel_wb_clk_i;
  assign rst	= caravel_wb_rst_i;
  clk_div_n div(
              .rst(rst),
              .clk(clk),
              .div_num(4),
              .clk_out(clk_npu)
            );

    npu_wb ram_wb(
                .clk_npu(clk_npu),
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

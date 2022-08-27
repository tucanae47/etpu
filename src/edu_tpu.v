`default_nettype none
`timescale 1ns/1ns

module edge_detect (
    input wire              clk,
    input wire              signal,
    output wire             leading_edge_detect
  );

  reg q0, q1, q2;                 // metastability on input and a delay to detect edges

  always @(posedge clk)
  begin
    q0 <= signal;
    q1 <= q0;
    q2 <= q1;
  end

  assign leading_edge_detect = q1 & (q2 != q1);

endmodule
module peek #(
    parameter WIDTH = 20)
  (
    input wire clk,
    input wire rst,
    input wire ack,
    output wire [WIDTH-1:0] period,
    output wire [2:0] ack_o
  );
  //  ack, ack_prev
  //  0,0
  //  1,0
  //  1,1
  //  0,1

  // reg [WIDTH-1:0]  acks,ticks;
  reg [2:0] acks =  8'd0;
  reg [WIDTH-1:0] ticks;
  reg [7:0] ack_in = 8'd0;
  reg ack_prev = 1'd0;
  always @(posedge clk)
  begin
    if (rst)
      ticks <=1;
    if (ack && acks < 3)
    begin
      acks <= acks + 1;
    end
    else if (acks > 0 && acks < 2)
    begin
      ticks<= ticks + 1;
    end
  end
  assign ack_o = acks;
  assign period = ticks;
endmodule

module clk_div_n #(
    parameter WIDTH = 64)

  (
    input wire clk,
    input wire rst,
    input wire en,
    input wire [21-1:0] div_num,
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
    else if (en)
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
  wire clk, rst, valid;
  reg				ready;
  assign clk 	= caravel_wb_clk_i;
  assign rst	= caravel_wb_rst_i;

  assign valid 	= caravel_wb_cyc_i & caravel_wb_stb_i;


  always@(posedge clk)
    if(rst | ready)
      ready <= 0;
    else if(valid & ~ready)
      ready <= 1;


  npu_wb ram_wb(
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

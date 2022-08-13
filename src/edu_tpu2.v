`default_nettype none
`timescale 1ns / 1ps

`define ARRAY_SIZE 3
`define CHANNEL 4
`define INPUT_SIZE 16
`define KERNEL_SIZE 2
`define THRESHOLD 2


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
    parameter   [7:0]   TPU_END_ADDR  = 8'd0,                  // default start address in RAM to read pattern
    parameter   [23:0]  BASE_ADDRESS    = 24'h3000_00        // base address
  )(

`ifdef USE_POWER_PINS
    inout vccd1,	// User area 1 1.8V supply
    inout vssd1,	// User area 1 digital ground
`endif

    input wire          caravel_wb_clk_i,       // clock, runs at system clock
    input wire          caravel_wb_rst_i,       // main system reset
    input wire          caravel_wb_stb_i,       // write strobe
    input wire          caravel_wb_cyc_i,       // cycle
    input wire          caravel_wb_we_i,        // write enable
    input wire  [3:0]   caravel_wb_sel_i,       // write word select
    input wire  [31:0]  caravel_wb_dat_i,       // data in
    input wire  [31:0]  caravel_wb_adr_i,       // address
    output          caravel_wb_ack_o,       // ack
    output [31:0]  caravel_wb_dat_o       // data out
  );

  localparam STATE_STOP           = 0;
  localparam STATE_RUN         = 1;
  // read
  reg				ready;
  wire		[31:0]	rdata;
  wire clk, reset, valid, we_img_ram;
  assign caravel_wb_dat_o = rdata;
  assign caravel_wb_ack_o = ready;

  // write
  wire	[23:0]	img_data;
  wire	[7:0]	w_addr;
  wire [23:0] debug;
  wire [47:0] npu_o;
  // assign debug = caravel_wb_adr_i[34:4];
  assign w_addr = caravel_wb_adr_i[7:0];
  assign clk 	= caravel_wb_clk_i;
  assign reset	= caravel_wb_rst_i;

  reg [2:0]   state_input,state_tpu;

  reg en;
  assign valid 	= caravel_wb_cyc_i & caravel_wb_stb_i;
  assign debug = caravel_wb_adr_i[31:8];

//   assign we_img_ram	= (caravel_wb_adr_i[31:4] == BASE_ADDRESS) & (caravel_wb_adr_i[1:0]==1) & valid & caravel_wb_we_i;
  assign we_img_ram	= (caravel_wb_adr_i[31:8] == BASE_ADDRESS) & valid & caravel_wb_we_i;

  always@(posedge clk)
    if(reset | ready)
      ready <= 0;
    else if(valid & ~ready)
      ready <= 1;


  dfframnpu
    #(
      .DWIDTH (24),
      .AWIDTH (9 )
    )
    img_dffram
    (
      .clk		(clk			),
      .clk2		(ready		),
      .we			(we_img_ram		),
      .dat_o		(				),
      .dat_o2		(rdata		),
      .dat_i		(caravel_wb_dat_i[23:0]),
      .adr_w		(w_addr	),
      .adr_r		(w_addr		),
      .en(en), 
      .out(npu_o)

    );


 always @(posedge clk)
  begin
    if(reset)
    begin
      en <=0;
      state_tpu <= STATE_STOP;
    end
    else
    begin
      // FSM for systolic array
      case(state_tpu)
        STATE_STOP:
        begin
          // load weigths async
           if (w_addr + 1 == 9) begin
              en<=1;
              state_tpu<= STATE_RUN;
           end
        end
        STATE_RUN:
        begin
          // en<=0;
        end
      endcase
    end
  end


`ifdef COCOTB_SIM

  `ifndef SCANNED
`define SCANNED
          initial
          begin
            $dumpfile ("wave.vcd");
            $dumpvars (0, edu_tpu);
            #1;
          end
`endif
`endif

        endmodule


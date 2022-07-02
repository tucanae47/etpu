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
    parameter   [31:0]  BASE_ADDRESS    = 32'h3000_0000        // base address
  )(

`ifdef USE_POWER_PINS
    inout vccd1,	// User area 1 1.8V supply
    inout vssd1,	// User area 1 digital ground
`endif

    input wire          caravel_wb_clk_i,       // clock, runs at system clock
    input wire          caravel_wb_rst_i,       // main system reset
    input wire          caravel_wb_rst2_i,       // main system reset
    input wire          caravel_wb_stb_i,       // write strobe
    input wire          caravel_wb_cyc_i,       // cycle
    input wire          caravel_wb_we_i,        // write enable
    input wire  [3:0]   caravel_wb_sel_i,       // write word select
    input wire  [31:0]  caravel_wb_dat_i,       // data in
    input wire  [31:0]  caravel_wb_adr_i,       // address
    output reg          caravel_wb_ack_o,       // ack
    output reg  [31:0]  caravel_wb_dat_o       // data out
  );

  localparam DSIZE = 24;
  localparam ASIZE = 4;
  wire  rclk;
  wire wclk,rst,rst2;
  clk_div_n div(
              .rst(rst),
              .clk(caravel_wb_clk_i),
              .div_num(4),
              .clk_out(rclk)
            );

  assign wclk = caravel_wb_clk_i;
  // assign clk = caravel_wb_clk_i;
  assign rst = caravel_wb_rst_i;
  assign rst2 = caravel_wb_rst2_i;

  reg  winc;
  reg  [DSIZE-1:0] wdata;
  reg              wrst_n;
  wire             wfull;
  wire             awfull;
  reg              rrst_n;
  reg              rinc;
  wire [DSIZE-1:0] rdata;
  wire             rempty;
  wire             arempty;
  async_fifo
    #(
    DSIZE,
    ASIZE
    )
    fifo
    (
    wclk,
    wrst_n,
    winc,
    wdata,
    wfull,
    awfull,
    rclk,
    rrst_n,
    rinc,
    rdata,
    rempty,
    arempty
    );

  reg [16*9-1:0] result_o;
  reg [96:0] weights;
  reg [120:0] stream;
  reg loading;
  wire [48:0] wgt;

  localparam STATE_STOP           = 0;
  localparam STATE_RUN         = 1;
  localparam STATE_LOAD           = 2;
  localparam STATE_LOAD2           = 3;
  localparam STATE_DORMANT           = 4;
  reg [2:0]   sys_state,sys_state2;
  reg [3:0] i, ops, i2;
  reg [4:0] o_data;
  reg [7:0] c1,c2,c3;
  wire [15:0] o1,o2,o3;
  reg [15:0] o_1,o_2,o_3;
  reg [23:0] input_i;

  reg en, clocked;
  // CaravelBus reads

  always @(posedge wclk)
  begin
    // return ack
    caravel_wb_ack_o <= (caravel_wb_stb_i && caravel_wb_adr_i == BASE_ADDRESS);

    if(rst)
    begin
      // en <=0;
      i<=0;
      i2<=0;
      ops<=0;
      wrst_n <= 0;
      sys_state <= STATE_LOAD;
      weights <= 96'b0;
      winc<= 0;
      // caravel_wb_ack_o <= 0;
      // caravel_wb_dat_o <= 0;
    end
    else
    begin
      // FSM for loading data
      case(sys_state)
        STATE_LOAD:
        begin
          if( i == 4)
          begin
            sys_state <= STATE_LOAD2;
            wdata<=0;
            winc<= 1;
          end
          else if(caravel_wb_stb_i && caravel_wb_cyc_i && caravel_wb_we_i && caravel_wb_ack_o && caravel_wb_adr_i == BASE_ADDRESS)
          begin
            weights [(i*32)+:32] <= caravel_wb_dat_i;
            i <= i + 1;
          end
        end
        STATE_LOAD2:
        begin
          if(caravel_wb_stb_i && caravel_wb_cyc_i && caravel_wb_we_i && caravel_wb_ack_o && caravel_wb_adr_i == BASE_ADDRESS)
          begin
            if (i2 > 2)
            begin
              sys_state <= STATE_DORMANT;
            end
            else
            begin
              i2 <=  i2 +1;
            end
            wdata <= caravel_wb_dat_i[23:0];
            // en<=1;
            
          end
        end
        default:
          sys_state <= STATE_DORMANT;
      endcase
    end
  end


  // we need another clock to stream data into the systolic array using wishbone bus
  always @(posedge rclk)
  begin
  if(rst2)
    begin
      rrst_n <= 0;
      rinc <=0;
      sys_state2 <= STATE_DORMANT;
    end
    else begin 
    // FSM for systolic array
    case(sys_state2)
      STATE_DORMANT:
      begin
        if(!arempty)
        begin
          en<=1;
          rinc<=1;
          sys_state2 <= STATE_RUN;
        end
      end
      STATE_RUN:
      begin
        if( ops > 6)
        begin
          sys_state2 <= STATE_STOP;
        end
        else
        begin
          if (ops > 0 && c1 < 3)
          begin
            result_o [(c1*16)+:16] <= o_1;
            c1 <= c1 +1;
          end
          if (ops > 1 && c2 < 6)
          begin
            result_o [(c2*16)+:16] <= o_2;
            c2 <= c2 +1;
          end
          if (ops > 2 && c3 < 9)
          begin
            result_o [(c3*16)+:16] <= o_3;
            c3 <= c3 +1;
          end
          ops<= ops +1;
        end
      end
      STATE_STOP:
      begin
        if (o_data > 4)
        begin
          o_data <= 4'b0;
          sys_state2 <= STATE_DORMANT;
          c1 <= 0;
          c2 <= 0;
          c3 <= 0;
          weights <= 96'b0;
        end
        else
        begin
          // write to the bus the result
          if(caravel_wb_stb_i && caravel_wb_cyc_i && !caravel_wb_we_i && caravel_wb_adr_i == BASE_ADDRESS)
          begin
            if (o_data == 4)
              caravel_wb_dat_o <= result_o[(o_data*32)+:16];
            else
              caravel_wb_dat_o <= result_o[(o_data*32)+:32];
            o_data <= o_data + 1;
          end
        end
      end
      default:
        sys_state2 <= STATE_DORMANT;
    endcase
  end
  end


  always @(*)
  begin
    o_1 = o1;
    o_2 = o2;
    o_3 = o3;
  end

  sysa sa(
         .clk(rclk),
         .rst(rst2),
         .en(en),
         .w(weights),
         .in(rdata),
         .out1(o1),
         .out2(o2),
         .out3(o3)
       );

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

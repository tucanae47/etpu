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

  localparam DSIZE = 32;
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

  // we need async fifo to keep to clocks one for the tpu and other for the input stream
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
  localparam STATE_INIT         = 5;
  localparam STATE_LOAD_W           = 2;
  localparam STATE_LOAD_I           = 3;
  localparam STATE_DORMANT           = 4;
  reg [2:0]   state_input,state_tpu;
  reg [3:0] w_count, ops, i_count;
  reg [5:0] ops_hidden;
  reg [4:0] o_data;
  reg [7:0] c1,c2,c3;
  wire [15:0] o1,o2,o3;
  reg [15:0] o_1,o_2,o_3;
  reg [23:0] input_i;
  reg [32:0] l_count;

  reg en, clocked;
  // CaravelBus reads

  always @(posedge wclk)
  begin
    // return ack
    caravel_wb_ack_o <= (caravel_wb_stb_i && caravel_wb_adr_i == BASE_ADDRESS);

    if(rst)
    begin
      // en <=0;
      w_count<=0;
      i_count<=0;
      wrst_n <= 1;
      state_input <= STATE_INIT;
      winc<= 0;
      ops_hidden <= 0;
      o_data <= 4'b0;
      caravel_wb_ack_o <= 0;
      caravel_wb_dat_o <= 0;
    end
    else
    begin
      // FSM for loading data
      case(state_input)
        STATE_INIT:
        begin
          state_input <= STATE_LOAD_W;
          winc<= 1;
          wrst_n <= 0;
          wdata <= 0;
           rinc<=1;
           rrst_n<=0;
        end
        STATE_LOAD_W:
        begin
          if( w_count > 2)
          begin
            state_input <= STATE_LOAD_I;
          end
          else if(caravel_wb_stb_i && caravel_wb_cyc_i && caravel_wb_we_i && caravel_wb_ack_o && caravel_wb_adr_i == BASE_ADDRESS)
          begin
            wdata<= caravel_wb_dat_i;
            w_count <= w_count + 1;
          end
        end
        STATE_LOAD_I:
        begin
          if(caravel_wb_stb_i && caravel_wb_cyc_i && caravel_wb_we_i && caravel_wb_ack_o && caravel_wb_adr_i == BASE_ADDRESS)
          begin
            if (i_count > 4)
            begin
              state_input <= STATE_DORMANT;
            end
            else
            begin
              i_count <=  i_count +1;
            end
            wdata <= caravel_wb_dat_i[23:0];

          end
        end
        STATE_DORMANT:
        begin
          if (o_data <= 4) begin
            if (ops_hidden > 7*4) begin
              if(caravel_wb_stb_i && caravel_wb_cyc_i && !caravel_wb_we_i && caravel_wb_adr_i == BASE_ADDRESS)
              begin
                if (o_data == 4)
                  caravel_wb_dat_o <= result_o[(o_data*32)+:16];
                else
                  caravel_wb_dat_o <= result_o[(o_data*32)+:32];
                o_data <= o_data + 1;
              end
            end
            else
              ops_hidden <= ops_hidden + 1;
          end
          else
            state_input<=STATE_DORMANT;

        end
        default:
          state_input <= STATE_DORMANT;
      endcase
    end
  end


  // we need another clock to stream data into the systolic array using wishbone bus
  always @(negedge rclk)
  begin
    if(rst2)
    begin
      result_o <= 144'b0;
      rrst_n <= 1;
      rinc <=0;
      ops<=0;
      l_count<=0;
      o_1 <= 16'b0;
      o_2 <= 16'b0;
      o_3 <= 16'b0;
      c1 <= 0;
      weights <= 96'b0;
      c2 <= 3;
      c3 <= 6;
      state_tpu <= STATE_INIT;
    end
    else
    begin
      // FSM for systolic array
      case(state_tpu)
        STATE_INIT:
        begin
        
          // load weigths async
          if( l_count > 2)
          begin
            en<=1;
          end
          else begin
            if (rdata > 0 ) begin
            weights [(l_count*32)+:32] <= rdata;
            l_count <= l_count + 1;
            end
          end
          // got an out already ?
          if( o_1 > 0)
            state_tpu <= STATE_RUN;
        end
        STATE_RUN:
        begin
          if( ops > 6)
          begin
            state_tpu <= STATE_STOP;
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
          state_tpu <= STATE_DORMANT;
        end
        default:
          state_tpu <= STATE_DORMANT;
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
         .w(0),
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


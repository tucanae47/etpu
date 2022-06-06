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
  wire [WIDTH-1:0] r_nxt;

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

    input wire          clock,       // clock, runs at system clock
    input wire          rst,       // main system rst
    input wire          wb_stb_i,       // write strobe
    input wire          wb_cyc_i,       // cycle
    input wire          wb_we_i,        // write enable
    input wire  [3:0]   wb_sel_i,       // write word select
    input wire  [31:0]  wb_dat_i,       // data in
    input wire  [31:0]  wb_adr_i,       // address
    output reg          wb_ack_o,       // ack
    output reg  [31:0]  wb_dat_o       // data out
  );

  wire clk2,clk;
  clk_div_n div(
              .rst(rst),
              .clk(clock),
              .div_num(4),
              .clk_out(clk2)
            );

  assign clk = clock;
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

  always @(posedge clk)
  begin
    if(rst)
    begin
      en <=0;
      i<=0;
      i2<=0;
      ops<=0;
      sys_state <= STATE_LOAD;
      sys_state2 <= STATE_DORMANT;
      weights = 96'b0;
      c1 <= 0;
      c2 <= 3;
      c3 <= 6;
      result_o = 144'b0;
      o_1 <= 16'b0;
      o_2 <= 16'b0;
      o_3 <= 16'b0;
      o_data <= 4'b0;
      wb_ack_o <= 0;
      wb_dat_o <= 0;
    end
    else
    begin
      // return ack

      wb_ack_o <= (wb_stb_i && wb_adr_i == BASE_ADDRESS);
      // FSM for loading data 
      case(sys_state)
        STATE_LOAD:
        begin
          if( i == 4)
          begin
            sys_state <= STATE_LOAD2;
          end
          else if(wb_stb_i && wb_cyc_i && wb_we_i && wb_ack_o && wb_adr_i == BASE_ADDRESS)
          begin
            weights [(i*32)+:32] <= wb_dat_i;
            i <= i + 1;
          end
        end
        STATE_LOAD2:
        begin
          if(wb_stb_i && wb_cyc_i && wb_we_i && wb_ack_o && wb_adr_i == BASE_ADDRESS)
          begin
            if (i2 > 2)
            begin
              sys_state <= STATE_DORMANT;
              sys_state2 <= STATE_RUN;
              result_o = 144'b0;
              c1 <= 0;
              c2 <= 3;
              c3 <= 6;
              o_1 <= 16'b0;
              o_2 <= 16'b0;
              o_3 <= 16'b0;
              o_data <= 4'b0;
            end
            else
            begin
              i2 <=  i2 +1;
            end
            input_i <= wb_dat_i[23:0];
            en<=1;
          end
        end
        default:
          sys_state <= STATE_DORMANT;
      endcase

    end
  end


  // we need another clock to stream data into the systolic array using wishbone bus
  always @(posedge clk2)
  begin

    wb_ack_o <= (wb_stb_i && wb_adr_i == BASE_ADDRESS);
    // FSM for systolic array
    case(sys_state2)
      STATE_RUN:
      begin
        // if (clk2)
        if(wb_stb_i && wb_cyc_i && wb_we_i && wb_ack_o && wb_adr_i == BASE_ADDRESS)
          input_i <= wb_dat_i[23:0];

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
          sys_state <= STATE_LOAD;
          sys_state2 <= STATE_DORMANT;
          c1 <= 0;
          c2 <= 0;
          c3 <= 0;
          weights <= 96'b0;
        end
        else
        begin
          // write to the bus the result
          if(wb_stb_i && wb_cyc_i && !wb_we_i && wb_adr_i == BASE_ADDRESS)
          begin
            if (o_data == 4)
              wb_dat_o <= result_o[(o_data*32)+:16];
            else
              wb_dat_o <= result_o[(o_data*32)+:32];
            o_data <= o_data + 1;
          end
        end
      end

      default:
        sys_state2 <= STATE_DORMANT;
    endcase

  end


  always @(*)
  begin
    o_1 = o1;
    o_2 = o2;
    o_3 = o3;
  end

  sysa sa(
         .clk(clk2),
         .rst(rst),
         .en(en),
         .w(weights),
         .in(input_i),
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


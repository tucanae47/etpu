`default_nettype none
`timescale 1ns / 1ps

`define ARRAY_SIZE 3
`define CHANNEL 4
`define INPUT_SIZE 16
`define KERNEL_SIZE 2
module top_systolic(
    input clk,
    input reset,
    input [31:0] data,
    output reg [31:0] out,
    input [23:0] input_i
  );

  reg [16*3-1:0] result_o1;
  reg [16*3-1:0] result_o2;
  reg [16*9-1:0] result_o;
  reg [16*3-1:0] result_o3;

  reg [96:0] weights;
  reg loading;
  wire [48:0] wgt;
  localparam STATE_STOP           = 0;
  localparam STATE_RUN         = 1;
  localparam STATE_LOAD           = 2;
  reg [2:0]   sys_state;
  reg [3:0] i, ops;
  reg [4:0] o_data;
  reg [7:0] c1,c2,c3;
  wire [15:0] o1,o2,o3;
  reg [15:0] o_1,o_2,o_3;
  reg [1:0] Z1 = 1'b0;

  reg en;


  always @(posedge clk)
  begin
    if(reset)
    begin
      // en <= 9'b1;
      en <=0;
      i<=0;
      ops<=0;
      sys_state <= STATE_LOAD;
      weights = 96'b0;
      c1 <= 0;
      c2 <= 0;
      c3 <= 0;
      result_o1 = 48'b0;
      result_o = 144'b0;
      result_o2 = 48'b0;
      result_o3 = 48'b0;
      o_1 <= 16'b0;
      o_2 <= 16'b0;
      o_3 <= 16'b0;
      o_data <= 4'b0;
      out <= 32'b0;
      // o_data<={31{Z1}};
    end
    else
    begin

      // FSM for systolic array
      case(sys_state)
        STATE_LOAD:
        begin
          if( i == 4)
          begin
            sys_state <= STATE_RUN;
          end
          weights [(i*32)+:32] <= data;
          i <= i + 1;
          en <= 1;
        end

        STATE_RUN:
        begin
          if( ops > 6)
          begin
            sys_state <= STATE_STOP;
            result_o <= {result_o1, result_o2, result_o3};
          end
          else begin
          if (ops > 0 && c1 < 3) begin
            result_o1 [(c1*16)+:16] <= o_1;
            c1 <= c1 +1;
          end
          if (ops > 1 && c2 < 3) begin
            result_o2 [(c2*16)+:16] <= o_2;
            c2 <= c2 +1;
          end
          if (ops > 2 && c3 < 3) begin
            result_o3 [(c3*16)+:16] <= o_3;
            c3 <= c3 +1;
          end
          ops <= ops + 1;
        end
        end

        STATE_STOP:
        begin
          // if (o_data == 3) begin
          //   out <= result_o[(o_data*32)+:16];
          // end
          // else if (o_data > 4) begin
          if (o_data > 4) begin
            out <= 32'b0;
            o_data <= 4'b0;
            sys_state <= STATE_LOAD;
            c1 <= 0;
            c2 <= 0;
            c3 <= 0;
          end
          else begin 
              out <= result_o[(o_data*32)+:32];
              o_data <= o_data + 1;
            // if (o_data < 3) begin
            //   out <= result_o[(o_data*32)+:32];
            //   o_data <= o_data + 1;
            // end
            // else if (o_data < 6) begin
            //   out <= result_o[(o_data*32)+:32];
            //   o_data <= o_data + 1;
            // end
            // else begin
            //   out <= result_o[(o_data*32)+:32];
            //   o_data <= o_data + 1;
            // end
          end
        end

        default:
          sys_state <= STATE_LOAD;
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
         .clk(clk),
         .rst(reset),
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
            $dumpvars (0, top_systolic);
            #1;
          end
`endif
    `endif
        endmodule

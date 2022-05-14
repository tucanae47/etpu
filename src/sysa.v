`default_nettype none
`timescale 1ns / 1ps


module sysa #(
    parameter N = 3
  )
  (
    input clk,
    input rst,
    // input [(N*N)-1:0] en,
    input en,
    input [(8*N*N)-1:0] w,
    input [(8*N)-1:0] in,
    // output reg [16*N-1:0] out
    output reg [9:0] out1,
    output reg [9:0] out2,
    output reg [9:0] out3
  );

  reg [9:0] zero = 10'b0;
  wire [7:0] r_11, r_12, r_13 ;
  wire [9:0] d_11, d_12, d_13 ;
  // 1
  pe pe_11(.clk(clk), .rst(rst), .en(en), .up(zero), .left(in[7:0]), .w(w[7:0]), .right(r_11), .down(d_11));
  pe pe_12(.clk(clk), .rst(rst), .en(en), .up(zero), .left(r_11), .w(w[15:8]), .right(r_12), .down(d_12));
  pe pe_13(.clk(clk), .rst(rst), .en(en), .up(zero), .left(r_12), .w(w[23:16]), .right(r_13), .down(d_13));

  //  2
  wire [7:0] r_21, r_22, r_23 ;
  wire [9:0] d_21, d_22, d_23 ;
  pe pe_21(.clk(clk), .rst(rst), .en(en), .up(d_11), .left(in[15:8]), .w(w[31:24]), .right(r_21), .down(d_21));
  pe pe_22(.clk(clk), .rst(rst), .en(en), .up(d_12), .left(r_21), .w(w[39:32]), .right(r_22), .down(d_22));
  pe pe_23(.clk(clk), .rst(rst), .en(en), .up(d_13), .left(r_22), .w(w[47:40]), .right(r_23), .down(d_23));
  //  3
  wire [7:0] r_31, r_32, r_33 ;
  wire [9:0] o_1, o_2, o_3 ;
  pe pe_31(.clk(clk), .rst(rst), .en(en), .up(d_21), .left(in[23:16]), .w(w[55:48]), .right(r_31), .down(o_1));
  pe pe_32(.clk(clk), .rst(rst), .en(en), .up(d_22), .left(r_31), .w(w[63:56]), .right(r_32), .down(o_2));
  pe pe_33(.clk(clk), .rst(rst), .en(en), .up(d_23), .left(r_32), .w(w[71:64]), .right(r_33), .down(o_3));



  always @(*)
  begin
    
      assign out1 = o_1;
      assign out2 = o_2;
      assign out3 = o_3;
  //   // out=  {o_3, o_2, o_1};
  end
endmodule


module dfframnpu
  #(
     parameter N = 3,
     parameter DWIDTH =16,
     parameter AWIDTH = 9
   )
   (

     input          				clk,
     input          				clk2,
     input          				we,
     input rst,
     input en,
     input  		[DWIDTH-1:0]	dat_i,
     input  		[AWIDTH-1:0]	adr_w,
     input  		[AWIDTH-1:0]	adr_r,
     output reg 	[DWIDTH-1:0]	dat_o,
     output reg 	[DWIDTH-1:0]	dat_o2,
     output reg [47:0] out
   );

  reg [DWIDTH-1:0] w [0:(2**AWIDTH)-1];
  reg [DWIDTH-1:0] out_m [0:(2**AWIDTH)-1];

  always @(posedge clk)
  begin
    if(we && ! en)
      w[adr_w] <= dat_i;
  end

  wire [7:0] in1,in2,in3;
  assign in1 = dat_i[7:0];
  assign in2 = dat_i[15:8];
  assign in3 = dat_i[23:16];

  reg [15:0] zero = 15'b0;
  reg [7:0] memout_addr = 8'd18;
  wire [7:0] r_11, r_12, r_13 ;
  wire [15:0] d_11, d_12, d_13 ;
  // 1
  pe pe_11(.clk(clk2), .rst(rst), .en(en), .up(zero), .left(in1), .w(w[0]), .right(r_11), .down(d_11));
  pe pe_12(.clk(clk2), .rst(rst), .en(en), .up(zero), .left(r_11), .w(w[1]), .right(r_12), .down(d_12));
  pe pe_13(.clk(clk2), .rst(rst), .en(en), .up(zero), .left(r_12), .w(w[2]), .right(r_13), .down(d_13));

  //  2
  wire [7:0] r_21, r_22, r_23 ;
  wire [15:0] d_21, d_22, d_23 ;
  pe pe_21(.clk(clk2), .rst(rst), .en(en), .up(d_11), .left(in2), .w(w[3]), .right(r_21), .down(d_21));
  pe pe_22(.clk(clk2), .rst(rst), .en(en), .up(d_12), .left(r_21), .w(w[4]), .right(r_22), .down(d_22));
  pe pe_23(.clk(clk2), .rst(rst), .en(en), .up(d_13), .left(r_22), .w(w[5]), .right(r_23), .down(d_23));
  //  3
  wire [7:0] r_31, r_32, r_33 ;
  wire [15:0] o_1, o_2, o_3 ;
  pe pe_31(.clk(clk2), .rst(rst), .en(en), .up(d_21), .left(in3), .w(w[6]), .right(r_31), .down(o_1));
  pe pe_32(.clk(clk2), .rst(rst), .en(en), .up(d_22), .left(r_31), .w(w[7]), .right(r_32), .down(o_2));
  pe pe_33(.clk(clk2), .rst(rst), .en(en), .up(d_23), .left(r_32), .w(w[8]), .right(r_33), .down(o_3));

  always @(posedge clk2)
  begin
    if (en)
    begin
      memout_addr<= memout_addr + 3;
      out_m[memout_addr + 1] <= o_1;
      out_m[memout_addr + 2] <= o_2;
      out_m[memout_addr + 3] <= o_3;
    end
    dat_o2 	<= w2[adr_r];
  end


endmodule







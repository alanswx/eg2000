module square_gen(
  input clk,
  input start,
  input [7:0] din,
  output reg done,
  output dout,
  input [23:0] stp
);

// 4Mhz/0.0024=1666 2^24/1666=10070
// 16MHZ -- * 4?
// 16mhz/0.0128=1250 2^ 
//parameter STP = 24'd20140;


// 35.468


// 16mhz is 4x clock, so we 1/4 the rate
//  parameter STP = 24'd5035;
  
//  parameter STP = 24'd13312;  
//  parameter STP = 24'd6656;// -- this seems close
  
parameter STP = 24'd3007; //  

	 
//13333.28	cycles
//6666.64	50%

//parameter STP = 24'd53684;

//parameter STP = 24'd161000;

reg [23:0] div;
reg [2:0] nbit;
reg [7:0] data;
reg [1:0] cnt;
reg en, pulse;

initial begin
  en = 0;
  nbit = 0;
  cnt = 0;
  div = 0;
end

assign dout = data[0] ? ~cnt[0] : ~cnt[1];

always @(posedge clk or posedge start)
  if (start) div <= 24'd0;
  else if (en) { pulse, div } <= div + STP;

always @(posedge pulse or posedge start) begin
  if (start) begin
    en <= 1'b1;
    done <= 1'b0;
    data <= din;
  end
  else if (en) begin
    cnt <= cnt + 2'd1;
    if (2'd3 == cnt)  begin
      cnt <= 2'd0;
      nbit <= nbit + 3'd1;
      data <= { 1'b0, data[7:1] };
      if (nbit == 3'd7) begin
        en <= 1'b0;
        done <= 1'b1;
      end
    end
  end
end

endmodule
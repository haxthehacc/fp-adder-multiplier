`timescale 1ns / 1ps

module adder_tb;
reg [31:0] operand_1,operand_2;
reg clk;
wire [31:0] Sum;

adder DUT(.operand_1(operand_1),.operand_2(operand_2),.clk(clk),.Sum(Sum));
initial 
begin 
clk=1'b0;
operand_1=32'b00111111111000000000000000000000; //1.75
operand_2=32'b01000001010110100000000000000000; //13.625
//Expected output: 0x41760000
#40
$display("%b\n",Sum);

operand_1=32'b00111111000110000000000000000000; //0.59375
operand_2=32'b01000001010110100000000000000000; //13.625
//Expected output: 0x41638000
// clk=1'b0;
#40
$display("%b\n",Sum);

//operand_1=32'b00111111010110000000000000000000; //0.84375
//operand_2=32'b01001001110110100000000000000000; //1785856
//Expected output: 0x49da0007
//#40
//$display("%b\n",Sum);

//operand_1=32'b00111111100110000000000000000000; //1.1875
//operand_2=32'b01000001110110100000000000000000; //27.25
//Expected output: 0x41e38000
//$display("%b\n",Sum);
//#50
$finish;
end
always #1 clk=!clk;
endmodule

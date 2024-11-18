`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.11.2024 14:39:52
// Design Name: 
// Module Name: adder_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module adder_tb;
reg [31:0] operand_1,operand_2;
reg clk;
wire [31:0] Sum;

adder DUT(.operand_1(operand_1),.operand_2(operand_2),.clk(clk),.Sum(Sum));
initial 
begin 
clk=1'b0;
operand_1=32'b00111111111000000000000000000000; //1.5 in decimal
operand_2=32'b01000001010110100000000000000000; //13.6875 in decimal
#40
$display("%b\n",Sum);

operand_1=32'b00111111000110000000000000000000; //0.59375
operand_2=32'b01000001010110100000000000000000; //13.6875
// clk=1'b0;
#40
$display("%b\n",Sum);

//operand_1=32'b00111111010110000000000000000000;
//operand_2=32'b01001001110110100000000000000000;
// #20
// $display("%b\n",Sum);

// operand_1=32'b00111111100110000000000000000000;
// operand_2=32'b01000001110110100000000000000000;
// $display("%b\n",Sum);
// #50
$finish;
end
always #1 clk=!clk;
endmodule
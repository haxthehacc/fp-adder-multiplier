`timescale 1ns / 1ps

module compandshift(cas_mantissa_1, cas_mantissa_2, 
                    cas_exponent_1, cas_exponent_2, clk, reset, 
                    cas_shifted_mantissa_1, cas_shifted_mantissa_2, 
                    cas_new_exponent, done_1);

input [23:0] cas_mantissa_1, cas_mantissa_2;
input [7:0] cas_exponent_1, cas_exponent_2;
input clk,reset;
output reg [23:0] cas_shifted_mantissa_1, cas_shifted_mantissa_2;
output reg [7:0] cas_new_exponent;
output reg done_1=0;
reg [7:0] diff; 

always @(posedge clk)
begin
    if(cas_exponent_1 == cas_exponent_2)
    begin
        cas_shifted_mantissa_1<=cas_mantissa_1;
        cas_shifted_mantissa_2<=cas_mantissa_2;
        cas_new_exponent<=cas_exponent_1+1'b1;
        done_1<=1;
    end
    else if(cas_exponent_1>cas_exponent_2)
    begin
        diff=cas_exponent_1-cas_exponent_2;
        cas_shifted_mantissa_1<=cas_mantissa_1;
        cas_shifted_mantissa_2<=(cas_mantissa_2>>diff);
        cas_new_exponent<=cas_exponent_1+1'b1;
        done_1<=1;
    end
    else if(cas_exponent_2>cas_exponent_1)
    begin
        diff=cas_exponent_2-cas_exponent_1;
        cas_shifted_mantissa_2<=cas_mantissa_2;
        cas_shifted_mantissa_1<=(cas_mantissa_1>>diff);
        cas_new_exponent<=cas_exponent_2+1'b1;
        done_1<=1;
    end
end
endmodule

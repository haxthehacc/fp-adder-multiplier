`timescale 1ns / 1ps

module adder(operand_1, operand_2, clk, Sum);

//Declaring input and outputs
input [31:0] operand_1;
input [31:0] operand_2;
input clk;
//input reset;
output [31:0] Sum;
reg [31:0] sum;
wire reset;
//Declaration of other variables
reg [7:0] exponent_1, exponent_2;
reg [23:0] mantissa_1, mantissa_2;
reg [7:0] new_exponent;
wire [7:0] exponent_final;
wire [23:0] mantissa_final;
reg [24:0] mantissa_sum;
reg [23:0] shifted_mantissa_1, shifted_mantissa_2;
wire [23:0] cas_shifted_mantissa_1, cas_shifted_mantissa_2;
wire [24:0] add_mantissa_sum;
reg [7:0] tmp_new_exponent;
wire [7:0] add_new_exponent;
wire [7:0] cas_new_exponent;


reg busy_1=0; //cas
reg busy_2=0; //addition
reg busy_3=0; //normalisation

compandshift cas(mantissa_1, mantissa_2, 
                 exponent_1, exponent_2, clk, reset, 
                 cas_shifted_mantissa_1, cas_shifted_mantissa_2, 
                 cas_new_exponent,done_1);
addition add(shifted_mantissa_1, shifted_mantissa_2, 
             tmp_new_exponent, clk, reset, 
             add_mantissa_sum, add_new_exponent, done_2); 
normalisation normalise(mantissa_sum, new_exponent, 
                        clk, reset, mantissa_final, 
                        exponent_final,done_3);

always @(posedge clk)
begin
    if(busy_1==0)
    begin
        exponent_1<=operand_1[30:23];
        exponent_2<=operand_2[30:23];
        mantissa_1<={1'b1, operand_1[22:0]};
        mantissa_2<={1'b1, operand_2[22:0]};
        busy_1<=1;    
    end
    else if (done_1==1 && busy_2==0)
    begin
        shifted_mantissa_1<=cas_shifted_mantissa_1;
        shifted_mantissa_2<=cas_shifted_mantissa_2;
        tmp_new_exponent<=cas_new_exponent;
        busy_1<=0;
        busy_2<=1;
    end
    else if(done_2==1 && busy_3==0)
    begin
        mantissa_sum <= add_mantissa_sum;
        new_exponent <= add_new_exponent;
        busy_2<=0;
        busy_3<=1;
    end
    else if(done_3==1)
    begin
        sum<={operand_1[31], exponent_final, mantissa_final[22:0]};
        busy_3<=0;
        //$display("module:%b",sum);
    end
end
assign Sum = sum; 
endmodule

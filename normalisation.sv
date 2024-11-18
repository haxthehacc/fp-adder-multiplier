`timescale 1ns / 1ps

module normalisation(mantissa_sum, new_exponent, clk, reset, mantissa_final, exponent_final, done_3);
input [24:0] mantissa_sum;
input [7:0] new_exponent;
input clk, reset;
output reg [23:0] mantissa_final;
output reg [7:0] exponent_final;
output reg done_3=0;
reg rst=0;

always @(posedge clk)
begin
    if(rst==0)
    begin
        mantissa_final<=mantissa_sum[24:1];
        exponent_final<=new_exponent;
        if(mantissa_final==mantissa_sum[24:1])
        begin
            rst<=1;
        end
    end
    else begin
        repeat(24) begin
            if(mantissa_final[23]==0)
            begin
                mantissa_final<=(mantissa_final<<1'b1);
                exponent_final<=exponent_final-1'b1;
            end
            else begin
                done_3<=1;
                rst<=0;
            end
        end
    end
end
endmodule

`timescale 1ns / 1ps

// Stage 3: Normalise the result of addition or subtraction.
//
// Handshake: enable pulses high for one cycle to start.
//            done pulses high for one cycle when outputs are valid.
//
// Two cases:
//   Overflow (mant_sum[24] == 1, only possible after addition):
//     Right-shift mantissa by 1, increment exponent.
//
//   Subtraction result (mant_sum[24] == 0):
//     Find the position of the leading 1 using a priority encoder (LZC).
//     Left-shift mantissa so bit 23 is the leading 1.
//     Decrement exponent by the shift amount.
//     Special case: if mant_sum == 0, output is +0.0 (sign handled by top level).
//
// Output:
//   mant_final[22:0] : normalised mantissa WITHOUT the hidden bit
//   exp_final[7:0]   : adjusted biased exponent

module normalisation (
    input  wire        clk,
    input  wire        enable,
    input  wire [24:0] mant_sum,
    input  wire [7:0]  exp_in,
    input  wire        do_sub,
    output reg  [22:0] mant_final,
    output reg  [7:0]  exp_final,
    output reg         done
);

    reg [4:0]  lz;      // leading zero count (0–24)
    reg [23:0] aligned; // 24-bit working mantissa

    // Leading zero count on bits [23:0] of mant_sum (bit 24 handled separately).
    // This is a combinational priority encoder — synthesises as a tree, not a loop.
    function automatic [4:0] count_leading_zeros;
        input [23:0] m;
        casez (m)
            24'b1???????????????????????: count_leading_zeros = 5'd0;
            24'b01??????????????????????: count_leading_zeros = 5'd1;
            24'b001?????????????????????: count_leading_zeros = 5'd2;
            24'b0001????????????????????: count_leading_zeros = 5'd3;
            24'b00001???????????????????: count_leading_zeros = 5'd4;
            24'b000001??????????????????: count_leading_zeros = 5'd5;
            24'b0000001?????????????????: count_leading_zeros = 5'd6;
            24'b00000001????????????????: count_leading_zeros = 5'd7;
            24'b000000001???????????????: count_leading_zeros = 5'd8;
            24'b0000000001??????????????: count_leading_zeros = 5'd9;
            24'b00000000001?????????????: count_leading_zeros = 5'd10;
            24'b000000000001????????????: count_leading_zeros = 5'd11;
            24'b0000000000001???????????: count_leading_zeros = 5'd12;
            24'b00000000000001??????????: count_leading_zeros = 5'd13;
            24'b000000000000001?????????: count_leading_zeros = 5'd14;
            24'b0000000000000001????????: count_leading_zeros = 5'd15;
            24'b00000000000000001???????: count_leading_zeros = 5'd16;
            24'b000000000000000001??????: count_leading_zeros = 5'd17;
            24'b0000000000000000001?????: count_leading_zeros = 5'd18;
            24'b00000000000000000001????: count_leading_zeros = 5'd19;
            24'b000000000000000000001???: count_leading_zeros = 5'd20;
            24'b0000000000000000000001??: count_leading_zeros = 5'd21;
            24'b00000000000000000000001?: count_leading_zeros = 5'd22;
            24'b000000000000000000000001: count_leading_zeros = 5'd23;
            24'b000000000000000000000000: count_leading_zeros = 5'd24; // zero
            default:                      count_leading_zeros = 5'd0;
        endcase
    endfunction

    always @(posedge clk) begin
        done <= 1'b0;

        if (enable) begin

            if (mant_sum == 25'b0) begin
                // Result is exactly zero
                mant_final <= 23'b0;
                exp_final  <= 8'b0;

            end else if (mant_sum[24]) begin
                // Overflow from addition: right-shift by 1, bump exponent
                // Truncate (no rounding here — add rounding later if needed)
                mant_final <= mant_sum[23:1];
                exp_final  <= exp_in + 8'd1;

            end else begin
                // Normal or subtraction result: find leading 1 in bits [23:0]
                lz      = count_leading_zeros(mant_sum[23:0]);
                aligned = mant_sum[23:0] << lz;
                // aligned[23] is now 1 (the hidden bit) — strip it for storage
                mant_final <= aligned[22:0];
                exp_final  <= exp_in - {3'b0, lz};
            end

            done <= 1'b1;
        end
    end

endmodule

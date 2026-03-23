`timescale 1ns / 1ps

// Stage 1: Compare, sort by magnitude, align mantissas, determine operation.
//
// Handshake: enable pulses high for one cycle to start.
//            done pulses high for one cycle when outputs are valid.
//
// Inputs carry the hidden bit already set by the top level:
//   mantissa = {1'b1, operand[22:0]}
//
// Outputs:
//   mant_a      : larger-magnitude mantissa (aligned, 24 bits)
//   mant_b      : smaller-magnitude mantissa (right-shifted to match exp_a, 24 bits)
//   exp_out     : biased exponent of the larger operand (this is the raw working exponent;
//                 the adder/normaliser will adjust it, NOT this module)
//   result_sign : sign of the result (sign of the larger-magnitude operand)
//   do_sub      : 1 if signs differ (need subtraction), 0 if same (need addition)

module compandshift (
    input  wire        clk,
    input  wire        enable,
    input  wire [23:0] mantissa_1,
    input  wire [23:0] mantissa_2,
    input  wire [7:0]  exponent_1,
    input  wire [7:0]  exponent_2,
    input  wire        sign_1,
    input  wire        sign_2,
    output reg  [23:0] mant_a,
    output reg  [23:0] mant_b,
    output reg  [7:0]  exp_out,
    output reg         result_sign,
    output reg         do_sub,
    output reg         done
);

    reg [7:0] diff;

    always @(posedge clk) begin
        done <= 1'b0; // default: done is low

        if (enable) begin
            do_sub <= sign_1 ^ sign_2;

            if (exponent_1 > exponent_2) begin
                // operand_1 has larger magnitude
                diff         = exponent_1 - exponent_2;
                mant_a       <= mantissa_1;
                mant_b       <= mantissa_2 >> diff;
                exp_out      <= exponent_1;
                result_sign  <= sign_1;

            end else if (exponent_2 > exponent_1) begin
                // operand_2 has larger magnitude
                diff         = exponent_2 - exponent_1;
                mant_a       <= mantissa_2;
                mant_b       <= mantissa_1 >> diff;
                exp_out      <= exponent_2;
                result_sign  <= sign_2;

            end else begin
                // exponents equal — compare mantissas to determine sign
                if (mantissa_1 >= mantissa_2) begin
                    mant_a      <= mantissa_1;
                    mant_b      <= mantissa_2;
                    result_sign <= sign_1;
                end else begin
                    mant_a      <= mantissa_2;
                    mant_b      <= mantissa_1;
                    result_sign <= sign_2;
                end
                exp_out <= exponent_1; // both equal
            end

            done <= 1'b1;
        end
    end

endmodule

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
//   mant_a      : larger-magnitude mantissa (unshifted, 24 bits)
//   mant_b      : smaller-magnitude mantissa (right-shifted to align, 24 bits)
//   exp_out     : biased exponent of the larger operand (normalisation adjusts it)
//   result_sign : sign of the result (sign of the larger-magnitude operand)
//   do_sub      : 1 if signs differ (subtraction needed), 0 if same (addition)
//   guard       : first bit shifted out of mant_b during alignment
//   round       : second bit shifted out of mant_b during alignment
//   sticky      : OR of all remaining bits shifted out of mant_b
//
// Guard/round/sticky are zero when exponents are equal (no shift needed).
// When diff >= 25 the entire mant_b is shifted out: mant_b=0, G=0, R=0, S=1
// (if mant_b was non-zero), which correctly rounds up in normalisation.

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
    output reg         guard,
    output reg         round_bit,
    output reg         sticky,
    output reg         done
);

    // Compute guard, round, sticky for a right-shift of 'diff' on 'mant'.
    // Uses a 48-bit extended mantissa to avoid losing bits before inspecting them.
    task automatic compute_grs;
        input  [23:0] mant;
        input  [7:0]  diff;
        output        g;
        output        r;
        output        s;

        reg [47:0] extended;
        reg [47:0] shifted;
        reg [7:0]  d;
        begin
            extended = {mant, 24'b0};   // mant occupies bits [47:24]; shifted-out bits land in [23:0]
            if (diff == 0) begin
                g = 1'b0; r = 1'b0; s = 1'b0;
            end else if (diff >= 25) begin
                // Entire mantissa shifted out
                g = 1'b0;
                r = 1'b0;
                s = (mant != 0);
            end else begin
                // Shift extended right by diff; the bits that "fell off" mant
                // are now in the upper portion of the lower 24 bits of extended>>diff
                shifted = extended >> diff;
                // Guard  = bit just below the new LSB of the aligned mantissa
                //        = bit (24 - diff) of extended before shift
                //        = bit 23 of shifted (the top of the fractional part)
                g = shifted[23];
                // Round  = next bit down
                r = (diff >= 2) ? shifted[22] : 1'b0;
                // Sticky = OR of everything below round
                s = (diff >= 3) ? (shifted[21:0] != 0) : 1'b0;
            end
        end
    endtask

    reg [7:0]  diff;
    reg        g, r, s;

    always @(posedge clk) begin
        done <= 1'b0;

        if (enable) begin
            do_sub <= sign_1 ^ sign_2;

            if (exponent_1 > exponent_2) begin
                diff = exponent_1 - exponent_2;
                compute_grs(mantissa_2, diff, g, r, s);
                mant_a      <= mantissa_1;
                mant_b      <= mantissa_2 >> diff;
                exp_out     <= exponent_1;
                result_sign <= sign_1;
                guard       <= g;
                round_bit   <= r;
                sticky      <= s;

            end else if (exponent_2 > exponent_1) begin
                diff = exponent_2 - exponent_1;
                compute_grs(mantissa_1, diff, g, r, s);
                mant_a      <= mantissa_2;
                mant_b      <= mantissa_1 >> diff;
                exp_out     <= exponent_2;
                result_sign <= sign_2;
                guard       <= g;
                round_bit   <= r;
                sticky      <= s;

            end else begin
                // Equal exponents — no shift, no lost bits
                if (mantissa_1 >= mantissa_2) begin
                    mant_a      <= mantissa_1;
                    mant_b      <= mantissa_2;
                    result_sign <= sign_1;
                end else begin
                    mant_a      <= mantissa_2;
                    mant_b      <= mantissa_1;
                    result_sign <= sign_2;
                end
                exp_out   <= exponent_1;
                guard     <= 1'b0;
                round_bit <= 1'b0;
                sticky    <= 1'b0;
            end

            done <= 1'b1;
        end
    end

endmodule

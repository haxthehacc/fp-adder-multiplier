`timescale 1ns / 1ps

// Stage 2: Add or subtract aligned mantissas.
//
// Handshake: enable pulses high for one cycle to start.
//            done pulses high for one cycle when outputs are valid.
//
// do_sub == 0: mant_sum = mant_a + mant_b  (25-bit; bit 24 is carry/overflow)
// do_sub == 1: mant_sum = mant_a - mant_b  (mant_a >= mant_b guaranteed by stage 1)
//              result fits in 24 bits; bit 24 will be 0.
//
// guard/round/sticky pass through unchanged for use by normalisation.
// exp_in passes through unchanged — normalisation adjusts it.

module addition (
    input  wire        clk,
    input  wire        enable,
    input  wire [23:0] mant_a,
    input  wire [23:0] mant_b,
    input  wire [7:0]  exp_in,
    input  wire        do_sub,
    input  wire        guard,
    input  wire        round_bit,
    input  wire        sticky,
    output reg  [24:0] mant_sum,
    output reg  [7:0]  exp_out,
    output reg         guard_out,
    output reg         round_out,
    output reg         sticky_out,
    output reg         done
);

    always @(posedge clk) begin
        done <= 1'b0;

        if (enable) begin
            if (do_sub)
                mant_sum <= {1'b0, mant_a} - {1'b0, mant_b};
            else
                mant_sum <= {1'b0, mant_a} + {1'b0, mant_b};

            exp_out    <= exp_in;
            guard_out  <= guard;
            round_out  <= round_bit;
            sticky_out <= sticky;
            done       <= 1'b1;
        end
    end

endmodule

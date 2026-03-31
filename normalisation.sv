`timescale 1ns / 1ps

// Stage 3: Normalise and round the result of addition or subtraction.
//
// Handshake: enable pulses high for one cycle to start.
//            done pulses high for one cycle when outputs are valid.
//
// Normalisation cases:
//   Zero:     mant_sum == 0  -> output +0
//   Overflow: mant_sum[24]   -> right-shift by 1, increment exponent
//                               the shifted-out bit becomes the new guard bit
//   Normal:   LZC left-shift, decrement exponent by shift amount
//             left-shift pushes guard/round/sticky out entirely (they become 0
//             because left-shifting a subtraction result never loses significant bits)
//
// Rounding (RNE — round to nearest, ties to even), applied after normalisation:
//   increment mantissa if:
//     G=1 AND (R=1 OR S=1)          -> strictly greater than halfway, round up
//     G=1 AND R=0 AND S=0 AND lsb=1 -> exactly halfway, round up only if odd (ties to even)
//   After rounding, if mantissa overflows (all 24 bits set + 1 = 2^24):
//     right-shift by 1, increment exponent again.

module normalisation (
    input  wire        clk,
    input  wire        enable,
    input  wire [24:0] mant_sum,
    input  wire [7:0]  exp_in,
    input  wire        do_sub,
    input  wire        guard,
    input  wire        round_bit,
    input  wire        sticky,
    output reg  [22:0] mant_final,
    output reg  [7:0]  exp_final,
    output reg         done
);

    // Leading zero count on bits [23:0] — combinational priority encoder.
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
            24'b000000000000000000000000: count_leading_zeros = 5'd24;
            default:                      count_leading_zeros = 5'd0;
        endcase
    endfunction

    reg [4:0]  lz;
    reg [23:0] norm_mant;   // 24-bit normalised mantissa (includes hidden bit)
    reg [7:0]  norm_exp;
    reg        g, r, s;     // working guard/round/sticky after normalisation step
    reg        round_up;    // final rounding decision

    always @(posedge clk) begin
        done <= 1'b0;

        if (enable) begin

            // --------------------------------------------------------
            // Step 1: Normalise
            // --------------------------------------------------------
            if (mant_sum == 25'b0) begin
                // Exact zero — skip rounding entirely
                mant_final <= 23'b0;
                exp_final  <= 8'b0;
                done       <= 1'b1;

            end else begin

                if (mant_sum[24]) begin
                    // Overflow carry from addition.
                    // Right-shift by 1; the bit shifted out of mant_sum[0]
                    // becomes the new guard bit. Old guard/round/sticky collapse:
                    //   new_g = old mant_sum[0]
                    //   new_r = old guard
                    //   new_s = old round | old sticky
                    norm_mant = mant_sum[24:1];          // 24 bits, bit23=1
                    norm_exp  = exp_in + 8'd1;
                    g         = mant_sum[0];
                    r         = guard;
                    s         = round_bit | sticky;

                end else begin
                    // Normal case: left-shift until bit 23 is 1.
                    // Left-shifting a subtraction result never pushes meaningful
                    // fractional bits in — GRS become 0 after any left shift.
                    lz        = count_leading_zeros(mant_sum[23:0]);
                    norm_mant = mant_sum[23:0] << lz;    // bit23=1 after shift
                    norm_exp  = exp_in - {3'b0, lz};
                    // After a left shift the fractional bits are gone
                    g         = 1'b0;
                    r         = 1'b0;
                    s         = 1'b0;
                    // Exception: if lz==0 (already normalised, came from addition
                    // without overflow), GRS from alignment still apply
                    if (lz == 0) begin
                        g = guard;
                        r = round_bit;
                        s = sticky;
                    end
                end

                // --------------------------------------------------------
                // Step 2: RNE rounding decision
                // --------------------------------------------------------
                // round_up if:
                //   G & (R | S)          — strictly above midpoint
                //   G & ~R & ~S & lsb=1  — exactly at midpoint, round to even
                round_up = g & (r | s | norm_mant[0]);

                // --------------------------------------------------------
                // Step 3: Apply rounding increment
                // --------------------------------------------------------
                if (round_up) begin
                    norm_mant = norm_mant + 24'd1;
                    // Check if rounding caused a carry out of bit 23
                    if (norm_mant[23] == 1'b0) begin
                        // norm_mant wrapped: 0xFFFFFF + 1 = 0x1000000
                        // but we're in 24 bits so it becomes 0x000000 with carry.
                        // Right-shift by 1 and bump exponent.
                        norm_mant = 24'h800000; // = 1.0 in 1.f format
                        norm_exp  = norm_exp + 8'd1;
                    end
                end

                // Strip hidden bit for storage
                mant_final <= norm_mant[22:0];
                exp_final  <= norm_exp;
                done       <= 1'b1;
            end
        end
    end

endmodule

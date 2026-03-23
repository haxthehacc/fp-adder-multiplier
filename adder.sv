`timescale 1ns / 1ps

// Top-level IEEE 754 single-precision floating point adder.
//
// Pipeline: compandshift -> addition -> normalisation
// Handshake: each stage is started by a one-cycle enable pulse and signals
//            completion with a one-cycle done pulse.
//
// Limitations (known, to be addressed in later passes):
//   - No rounding (truncates to 23 bits)
//   - No NaN / Infinity / denormal handling
//   - No overflow/underflow detection on the final exponent

module adder (
    input  wire        clk,
    input  wire        start,       // pulse high for one cycle to begin a new operation
    input  wire [31:0] operand_1,
    input  wire [31:0] operand_2,
    output reg  [31:0] Sum,
    output reg         done
);

    // ----------------------------------------------------------------
    // Sub-module interconnect wires
    // ----------------------------------------------------------------

    // Stage 1 (compandshift) outputs
    wire [23:0] cas_mant_a;
    wire [23:0] cas_mant_b;
    wire [7:0]  cas_exp_out;
    wire        cas_result_sign;
    wire        cas_do_sub;
    wire        cas_done;

    // Stage 2 (addition) outputs
    wire [24:0] add_mant_sum;
    wire [7:0]  add_exp_out;
    wire        add_done;

    // Stage 3 (normalisation) outputs
    wire [22:0] norm_mant_final;
    wire [7:0]  norm_exp_final;
    wire        norm_done;

    // ----------------------------------------------------------------
    // Stage enable registers (each pulsed for one cycle by sequencer)
    // ----------------------------------------------------------------
    reg cas_enable;
    reg add_enable;
    reg norm_enable;

    // ----------------------------------------------------------------
    // Registers to hold inter-stage data latched by the sequencer
    // ----------------------------------------------------------------
    reg [23:0] r_mant_a;
    reg [23:0] r_mant_b;
    reg [7:0]  r_cas_exp;
    reg        r_do_sub;
    reg        r_result_sign;

    reg [24:0] r_mant_sum;
    reg [7:0]  r_add_exp;

    // ----------------------------------------------------------------
    // Sub-module instantiations
    // ----------------------------------------------------------------
    compandshift cas (
        .clk         (clk),
        .enable      (cas_enable),
        .mantissa_1  ({1'b1, operand_1[22:0]}),
        .mantissa_2  ({1'b1, operand_2[22:0]}),
        .exponent_1  (operand_1[30:23]),
        .exponent_2  (operand_2[30:23]),
        .sign_1      (operand_1[31]),
        .sign_2      (operand_2[31]),
        .mant_a      (cas_mant_a),
        .mant_b      (cas_mant_b),
        .exp_out     (cas_exp_out),
        .result_sign (cas_result_sign),
        .do_sub      (cas_do_sub),
        .done        (cas_done)
    );

    addition add (
        .clk      (clk),
        .enable   (add_enable),
        .mant_a   (r_mant_a),
        .mant_b   (r_mant_b),
        .exp_in   (r_cas_exp),
        .do_sub   (r_do_sub),
        .mant_sum (add_mant_sum),
        .exp_out  (add_exp_out),
        .done     (add_done)
    );

    normalisation norm (
        .clk        (clk),
        .enable     (norm_enable),
        .mant_sum   (r_mant_sum),
        .exp_in     (r_add_exp),
        .do_sub     (r_do_sub),
        .mant_final (norm_mant_final),
        .exp_final  (norm_exp_final),
        .done       (norm_done)
    );

    // ----------------------------------------------------------------
    // Sequencer FSM
    // ----------------------------------------------------------------
    typedef enum logic [2:0] {
        IDLE    = 3'd0,
        S1_WAIT = 3'd1,
        S1_LATCH= 3'd2,
        S2_WAIT = 3'd3,
        S2_LATCH= 3'd4,
        S3_WAIT = 3'd5,
        FINISH  = 3'd6
    } state_t;

    state_t state;

    always @(posedge clk) begin
        // Default: all enables low, done low
        cas_enable  <= 1'b0;
        add_enable  <= 1'b0;
        norm_enable <= 1'b0;
        done        <= 1'b0;

        case (state)

            IDLE: begin
                if (start) begin
                    cas_enable <= 1'b1;   // kick off stage 1
                    state      <= S1_WAIT;
                end
            end

            S1_WAIT: begin
                if (cas_done) begin
                    // Latch stage 1 outputs
                    r_mant_a     <= cas_mant_a;
                    r_mant_b     <= cas_mant_b;
                    r_cas_exp    <= cas_exp_out;
                    r_do_sub     <= cas_do_sub;
                    r_result_sign<= cas_result_sign;
                    add_enable   <= 1'b1; // kick off stage 2
                    state        <= S2_WAIT;
                end
            end

            S2_WAIT: begin
                if (add_done) begin
                    // Latch stage 2 outputs
                    r_mant_sum  <= add_mant_sum;
                    r_add_exp   <= add_exp_out;
                    norm_enable <= 1'b1;  // kick off stage 3
                    state       <= S3_WAIT;
                end
            end

            S3_WAIT: begin
                if (norm_done) begin
                    // Assemble final IEEE 754 result
                    Sum   <= {r_result_sign, norm_exp_final, norm_mant_final};
                    done  <= 1'b1;
                    state <= IDLE;
                end
            end

            default: state <= IDLE;

        endcase
    end

    // Reset / init
    initial begin
        state       = IDLE;
        cas_enable  = 1'b0;
        add_enable  = 1'b0;
        norm_enable = 1'b0;
        done        = 1'b0;
        Sum         = 32'b0;
    end

endmodule

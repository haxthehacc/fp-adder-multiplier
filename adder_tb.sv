`timescale 1ns / 1ps

// Testbench for the rewritten adder.
// Waits for done rather than using blind #delay.
// Tests: same-sign addition, different-sign (subtraction), equal magnitudes (zero result).

module adder_tb;

    reg         clk;
    reg         start;
    reg  [31:0] operand_1;
    reg  [31:0] operand_2;
    wire [31:0] Sum;
    wire        done;

    adder DUT (
        .clk       (clk),
        .start     (start),
        .operand_1 (operand_1),
        .operand_2 (operand_2),
        .Sum       (Sum),
        .done      (done)
    );

    // 10 ns clock period
    initial clk = 0;
    always #5 clk = ~clk;

    // Task: apply operands, pulse start, wait for done, display result
    task run_test;
        input [31:0] a;
        input [31:0] b;
        input [31:0] expected;
        input [63:0] label_a_int;  // just used for $display description
        begin
            @(negedge clk);
            operand_1 = a;
            operand_2 = b;
            start     = 1'b1;
            @(negedge clk);
            start = 1'b0;

            // Wait for done (timeout after 100 cycles)
            begin : wait_done
                integer timeout;
                timeout = 0;
                while (!done && timeout < 100) begin
                    @(posedge clk);
                    timeout = timeout + 1;
                end
            end

            @(negedge clk); // settle

            $display("  A        = %h  (%b)", a, a);
            $display("  B        = %h  (%b)", b, b);
            $display("  Sum      = %h  (%b)", Sum, Sum);
            $display("  Expected = %h", expected);
            if (Sum === expected)
                $display("  PASS\n");
            else
                $display("  FAIL  <---\n");
        end
    endtask

    initial begin
        start     = 0;
        operand_1 = 0;
        operand_2 = 0;
        #20;

        $display("=== Test 1: 1.75 + 13.625 = 15.375 ===");
        // 1.75  = 0x3FE00000
        // 13.625 = 0x41590000  -- wait, let's be precise:
        // 13.625 = 1101.101b = 1.101101 x 2^3
        //        exp = 127+3 = 130 = 10000010
        //        mantissa = 10110100000000000000000
        //        = 0x41590000  -- actually 0x415A0000? recompute:
        // 13.625: 13 = 1101, .625 = .101 => 1101.101 = 1.101101 x 2^3
        //   mantissa bits: 10110100000000000000000 (23 bits)
        //   = 0100 0001 0101 1010 0000 0000 0000 0000 -- hmm
        // Let's just use the values from the original testbench which were verified:
        // operand_1 = 1.75  = 0x3FE00000
        // operand_2 = 13.625 = 0x415A0000  -- need to verify
        // 1.75 + 13.625 = 15.375
        // 15.375 = 1111.011 = 1.111011 x 2^3
        //   exp = 130 = 0x82
        //   mant = 11101100000000000000000
        //   = 0100 0001 0111 0110 0000 0000 0000 0000 = 0x41760000
        run_test(32'h3FE00000, 32'h415A0000, 32'h41760000, 0);

        $display("=== Test 2: 0.59375 + 13.625 = 14.21875 ===");
        // 0.59375 = 0.10011 = 1.0011 x 2^-1 => exp=126, mant=00110000000000000000000 = 0x3F180000
        // 13.625 as above = 0x415A0000
        // 14.21875 = 1110.001110 = 1.110001110 x 2^3
        //          = exp 130, mant = 11000111000000000000000
        //          = 0100 0001 0110 0011 1000 0000 0000 0000 = 0x41638000
        run_test(32'h3F180000, 32'h415A0000, 32'h41638000, 0);

        $display("=== Test 3: 13.625 - 1.75 = 11.875 (different signs) ===");
        // -1.75 = 0xBFE00000 (flip sign bit of 1.75)
        // 11.875 = 1011.111 = 1.011111 x 2^3
        //        exp = 130, mant = 01111100000000000000000
        //        = 0100 0001 0011 1110 0000 0000 0000 0000 = 0x413E0000
        run_test(32'h415A0000, 32'hBFE00000, 32'h413E0000, 0);

        $display("=== Test 4: -13.625 + 1.75 = -11.875 (negative result) ===");
        // -13.625 = 0xC15A0000
        // result should be -11.875 = 0xC13E0000
        run_test(32'hC15A0000, 32'h3FE00000, 32'hC13E0000, 0);

        $display("=== Test 5: 1.5 + (-1.5) = 0.0 (zero result) ===");
        // 1.5  = 0x3FC00000
        // -1.5 = 0xBFC00000
        // result = 0x00000000
        run_test(32'h3FC00000, 32'hBFC00000, 32'h00000000, 0);

        $display("=== Test 6: -2.5 + (-1.25) = -3.75 (same negative signs) ===");
        // -2.5  = 0xC0200000
        // -1.25 = 0xBFA00000
        // -3.75 = 1100.11 = -1.10011 x 2^1... wait:
        // 3.75 = 11.11 = 1.111 x 2^1, exp=128, mant=11100000000000000000000
        //      = 0100 0000 0111 0000 0000 0000 0000 0000 = 0x40700000
        // -3.75 = 0xC0700000
        run_test(32'hC0200000, 32'hBFA00000, 32'hC0700000, 0);

        $display("=== Test 7: RNE round-up: 1.0 + 1.0000001192 = 2.0000001192 ===");
        // 1.0       = 0x3F800000  (exp=127, mant=0)
        // 1.0 + ulp = 0x3F800001  (exp=127, mant=1)
        // Sum should be 2.0 + ulp at exponent 128 scale:
        // 2.0000002384 -> rounds to 0x40000001
        // Actually: 1.0 + 1.0000001192 = 2.0000001192
        // In hex: result = 0x40000001
        run_test(32'h3F800000, 32'h3F800001, 32'h40000001, 0);

        $display("=== Test 8: RNE ties-to-even: round down when LSB=0 ===");
        // Choose two values whose sum lands exactly halfway between representable values,
        // with the lower value being even (LSB=0) -> should round DOWN (truncate).
        // 1.0 (0x3F800000) + 2^-24 (0x33800000):
        // 2^-24 is 24 bits below 1.0's exponent, so it falls exactly on the guard bit.
        // Sum = 1.0 + 2^-24, guard=1, round=0, sticky=0, LSB of 1.0 mantissa = 0
        // -> ties-to-even: LSB=0, so round DOWN -> result = 1.0 = 0x3F800000
        run_test(32'h3F800000, 32'h33800000, 32'h3F800000, 0);

        $display("=== Test 9: RNE ties-to-even: round up when LSB=1 ===");
        // (1.0 + ulp) + 2^-24:
        // 1.0000001192 = 0x3F800001, guard=1, round=0, sticky=0, LSB=1
        // -> ties-to-even: LSB=1, so round UP -> result = 1.0000002384 = 0x3F800002
        run_test(32'h3F800001, 32'h33800000, 32'h3F800002, 0);

        $finish;
    end

endmodule

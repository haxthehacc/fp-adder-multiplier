`timescale 1ns / 1ps

module multiplier_tb();

reg [31:0] operand_1, operand_2;
reg clk, reset;
wire [31:0] Product;

// Instantiate the multiplier
multiplier uut (
    .operand_1(operand_1),
    .operand_2(operand_2),
    .clk(clk),
    .Product(Product),
    .reset(reset)
);

// Clock generation
initial begin
    clk = 0;
    forever #5 clk = ~clk; // 10ns clock period
end

// Stimulus
initial begin
    reset = 1; #10;
    reset = 0;

    // Test Case 1: 1.5 * 2.75
    operand_1 = 32'h3FC00000; // 1.5 in IEEE 754
    operand_2 = 32'h40300000; // 2.75 in IEEE 754
    // Expected result: 1.5 * 2.75 = 4.125 = 0x40840000
    #100;

    // Test Case 2: 0.5 * -4.0
    operand_1 = 32'h3F000000; // 0.5 in IEEE 754
    operand_2 = 32'hC0800000; // -4.0 in IEEE 754
    // Expected result: 0.5 * -4.0 = -2.0 = 0xC0000000
    #100;

    // Test Case 3: -2.5 * -1.25
    operand_1 = 32'hC0200000; // -2.5 in IEEE 754
    operand_2 = 32'hBF400000; // -1.25 in IEEE 754
    // Expected result: -2.5 * -1.25 = 3.125 = 0x404A0000
    #200;

    $finish;
end

endmodule


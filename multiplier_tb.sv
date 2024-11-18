`timescale 1ns / 1ps

module multiplier_tb();

reg [31:0] operand_1, operand_2;
reg clk, reset;
wire [31:0] Product;

multiplier uut (
    .operand_1(operand_1),
    .operand_2(operand_2),
    .clk(clk),
    .Product(Product),
    .reset(reset)
);

initial begin
    clk = 0;
    forever #5 clk = ~clk; 
end

initial begin
    reset = 1; #10;
    reset = 0;

    operand_1 = 32'h3FC00000; // 1.5
    operand_2 = 32'h40300000; // 2.75
    // Expected output: 0x40840000
    #100;

    // Test Case 2: 0.5 * -4.0
    operand_1 = 32'h3F000000; // 0.5 in IEEE 754
    operand_2 = 32'hC0800000; // -4.0 in IEEE 754
    // Expected output: 0xC0000000
    #100;

    // Test Case 3: -2.5 * -1.25
    operand_1 = 32'hC0200000; // -2.5 in IEEE 754
    operand_2 = 32'hBF400000; // -1.25 in IEEE 754
    // Expected output: 0x40480000
    #200;

    $finish;
end

endmodule


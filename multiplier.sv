`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 17.11.2024 10:35:45
// Design Name: 
// Module Name: multiplier
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

    
module multiplier(input clk, reset,
                  input [31:0] operand_1,
                  input [31:0] operand_2,
                  output reg [31:0] Product,
                  output reg done);

    reg [2:0] counter;

    reg [23:0] a_m, b_m, p_m;
    reg [9:0] a_e, b_e, p_e;
    reg a_s, b_s, p_s;

    reg [49:0] intermediate_product;

    reg guard_bit, round_bit, sticky;

    // Counter logic for managing operations
    always @(posedge clk or posedge reset) begin
        if (reset) 
            counter <= 0;
        else 
            counter <= counter + 1;
    end

    // Step 1: Extract sign, exponent, and mantissa from inputs
    always @(posedge clk) begin
        if (counter == 3'b001) begin
            a_m <= operand_1[22:0];
            b_m <= operand_2[22:0];
            a_e <= operand_1[30:23] - 127;
            b_e <= operand_2[30:23] - 127;
            a_s <= operand_1[31];
            b_s <= operand_2[31];
        end
    end

    // Step 2: Handle special cases (NaN, Infinity, Zero)
    always @(posedge clk) begin
        if (counter == 3'b010) begin
            if ((a_e == 128 && a_m != 0) || (b_e == 128 && b_m != 0)) begin
                // NaN
                Product <= {1'b1, 8'hFF, 1'b1, 22'b0};
                done <= 1;
            end else if (a_e == 128) begin
                // Operand A is infinity
                Product <= {a_s ^ b_s, 8'hFF, 23'b0};
                if (($signed(b_e) == -127) && (b_m == 0)) // NaN if B is 0
                    Product <= {1'b1, 8'hFF, 1'b1, 22'b0};
                done <= 1;
            end else if (b_e == 128) begin
                // Operand B is infinity
                Product <= {a_s ^ b_s, 8'hFF, 23'b0};
                if (($signed(a_e) == -127) && (a_m == 0)) // NaN if A is 0
                    Product <= {1'b1, 8'hFF, 1'b1, 22'b0};
                done <= 1;
            end else if (($signed(a_e) == -127) && (a_m == 0)) begin
                // Operand A is zero
                Product <= {a_s ^ b_s, 8'b0, 23'b0};
                done <= 1;
            end else if (($signed(b_e) == -127) && (b_m == 0)) begin
                // Operand B is zero
                Product <= {a_s ^ b_s, 8'b0, 23'b0};
                done <= 1;
            end else begin
                // Normalize inputs
                if ($signed(a_e) == -127)
                    a_e <= -126;
                else
                    a_m[23] <= 1;

                if ($signed(b_e) == -127)
                    b_e <= -126;
                else
                    b_m[23] <= 1;
            end
        end
    end

    // Step 3: Normalize mantissas
    always @(posedge clk) begin
        if (counter == 3'b011) begin
            if (!a_m[23]) begin
                a_m <= a_m << 1;
                a_e <= a_e - 1;
            end
            if (!b_m[23]) begin
                b_m <= b_m << 1;
                b_e <= b_e - 1;
            end
        end
    end

    // Step 4: Perform multiplication
    always @(posedge clk) begin
        if (counter == 3'b100) begin
            p_s <= a_s ^ b_s;
            p_e <= a_e + b_e + 1;
            intermediate_product <= a_m * b_m * 4;
        end
    end

    // Step 5: Extract mantissa and rounding bits
    always @(posedge clk) begin
        if (counter == 3'b101) begin
            p_m <= intermediate_product[49:26];
            guard_bit <= intermediate_product[25];
            round_bit <= intermediate_product[24];
            sticky <= (intermediate_product[23:0] != 0);
        end
    end

    // Step 6: Normalize and round the result
    always @(posedge clk) begin
        if (counter == 3'b110) begin
            if ($signed(p_e) < -126) begin
                p_e <= p_e + (-126 - $signed(p_e));
                p_m <= p_m >> (-126 - $signed(p_e));
                guard_bit <= p_m[0];
                round_bit <= guard_bit;
                sticky <= sticky | round_bit;
            end else if (!p_m[23]) begin
                p_e <= p_e - 1;
                p_m <= p_m << 1;
                p_m[0] <= guard_bit;
                guard_bit <= round_bit;
                round_bit <= 0;
            end else if (guard_bit && (round_bit | sticky | p_m[0])) begin
                p_m <= p_m + 1;
                if (p_m == 24'hffffff)
                    p_e <= p_e + 1;
            end
        end
    end
    // Step 7: Assemble the final result
    always @(posedge clk) begin
        if (counter == 3'b111) begin
            Product[22:0] <= p_m[22:0];
            Product[30:23] <= p_e[7:0] + 127;
            Product[31] <= p_s;
            if ($signed(p_e) == -126 && !p_m[23])
                Product[30:23] <= 0;
            if ($signed(p_e) > 127) begin // Overflow, return infinity
                Product <= {p_s, 8'hFF, 23'b0};
            end
            done <= 1;
        end
    end

endmodule

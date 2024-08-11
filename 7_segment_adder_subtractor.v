module input_select(
    input reset,                   // Input signal for reset
    input btn,                     // Input signal for button press
    output reg [3:0] user_choice = 4'b0000   // 4-bit output to store user's choice initialized to 0
);

always @(posedge btn or posedge reset) begin  // Trigger on rising edge of button or reset

    if (reset) begin
        user_choice <= 4'b0000;               // Set user_choice to 0 on reset
    end else begin
        // If user_choice is 9, set user_choice to 0. Otherwise, increment user_choice by 1
        user_choice <= (user_choice == 4'b1001) ? 4'b0000 : user_choice + 1;
    end
end
endmodule


module full_adder(
    input A, B, C,        // Inputs A, B, and C (carry-in)
    output F, G           // Outputs F (sum) and G (carry-out)
);

    assign F = A ^ B ^ C; // Sum output (XOR operation for three inputs)
    
    assign G = (A & B) | (B & C) | (A & C); // Carry-out output (carry generated if two or more inputs are high)
endmodule


module ripple_carry(
    input [3:0] A, B,      // 4-bit input operands A and B
    input C,               // MODE SELECTOR for addition or subtraction
    output [3:0] S,        // 4-bit output for sum or difference
    output Carry           // Carry-out signal
);

    wire [3:0] B_inverted = ~B;     // Invert B for subtraction (two's complement)
    wire [4:0] carries;             // Internal carries for each full adder

    assign carries[0] = C;          // Set initial carry for mode selection

    // Instantiate full adders for each bit
    full_adder FA0(A[0], C ? B_inverted[0] : B[0], carries[0], S[0], carries[1]); // LSB
    full_adder FA1(A[1], C ? B_inverted[1] : B[1], carries[1], S[1], carries[2]);
    full_adder FA2(A[2], C ? B_inverted[2] : B[2], carries[2], S[2], carries[3]);
    full_adder FA3(A[3], C ? B_inverted[3] : B[3], carries[3], S[3], carries[4]); // MSB

    assign Carry = carries[4];      // Connect the final carry out to the Carry output
endmodule


module output_splitter(                                                             /* When mode_select is 1 (subtraction), the module flips the most significant bit*/
    input Initial_A, A, B, C, D, E,     // 5 bit binary result from adder           /* of the 5 bit result before interpreting it. This has to be done to ensure the */
    input mode_select,                  // Mode select input                        /* proper output on the display. */
    output [3:0] I,                     // Left 7 seg digit
    output [3:0] J                      // Right 7 seg digit
);
    // Flip the MSB of input when mode_select is 1 (subtraction)
    assign A = mode_select ? ~Initial_A : Initial_A;

    assign I[0] = ~A & B & ~C & D | ~A & B & C | A & ~B & ~C & ~D | A & ~B & ~C & D & ~E;
    assign I[1] = A & B | A & C & D & E;
    assign I[2] = 0;
    assign I[3] = A & B | A & C & D & E;

    assign J[0] = ~C & ~D & E | ~A & ~C & D & E | B & ~C & D & E | C & D & E | ~A & C & ~D & E | B & C & ~D & E;
    assign J[1] = ~A & ~B & D | ~A & B & C & ~D | B & C & ~D & E | A & B & D & ~E | A & ~C & ~D & E | A & ~B & ~C & ~D;
    assign J[2] = A & ~B & ~C & ~D | A & ~C & ~D & E | A & B & ~C & E | A & B & ~C & D | ~A & B & C & D | ~A & ~B & C;
    assign J[3] = ~A & B & ~C & ~D | A & B & ~C & ~D & ~E | A & ~B & ~C & D & ~E | A & ~B & C & D & E;
endmodule


module mux_2to1(
    input [3:0] A, B,           // 4-bit inputs A and B
    input S,                    // Selector input
    output [3:0] F              // 4-bit output
);

    assign F = S ? B : A;       // If S is high, select B; otherwise, select A
endmodule


module anode_selector(
    input clk,               // Clock input
    output reg selector = 0  // One-bit selector output initialized to 0
);

    always @(posedge clk) begin
        selector <= ~selector;   // Toggle the selector on each positive clock edge
    end
endmodule


module seg7_4bit_1digit_decoder(        // Convert 4-bit binary to 7-segment display code, active high
   input [3:0] bin,                     // 4 bit binary input
   output reg [6:0] seg7                // LED cathode outputs, active high, assumes common anode LEDs
);                                      // Declare seg7 as a reg type for procedural assignments

always @(bin)
    begin
       case(bin)
            // Bit order is segments ABCDEFG
            // Active high: 1 turns the segment on and 0 turns the segment off
            4'b0000: seg7 = 7'b1111110; // "0"
            4'b0001: seg7 = 7'b0110000; // "1"
            4'b0010: seg7 = 7'b1101101; // "2"
            4'b0011: seg7 = 7'b1111001; // "3"
            4'b0100: seg7 = 7'b0110011; // "4"
            4'b0101: seg7 = 7'b1011011; // "5"
            4'b0110: seg7 = 7'b1011111; // "6"
            4'b0111: seg7 = 7'b1110000; // "7"
            4'b1000: seg7 = 7'b1111111; // "8"
            4'b1001: seg7 = 7'b1111011; // "9"
            4'b1010: seg7 = 7'b0000001; // "-"
       endcase
    end
endmodule


module top(
    input clk,
    input btn_inc1,
    input btn_reset,
    input btn_inc2,
    input mode_select,
    input equals_switch,
    output [6:0] seg7_output
);

    // Outputs from input_select modules
    wire [3:0] user_choice1;
    wire [3:0] user_choice2;

	// Output from ripple_carry
	wire [4:0] adder_output;

	// Output from anode_selector
	wire anode_select_output;

	// Outputs from output_splitter
    wire [3:0] splitter_output1;
    wire [3:0] splitter_output2;

	// Outputs from mux_2to1 modules
    wire [3:0] mux_output1;
    wire [3:0] mux_output2;
	wire [3:0] mux_output3;
    
	// Output from seg7_4bit_1digit_decoder
	wire [6:0] seg7_output;


    // Instantiate first input_select
    input_select Input_Selector_1 (
        .reset(btn_reset),
        .btn(btn_inc1),
        .user_choice(user_choice1)
    );

    // Instantiate second input_select
    input_select Input_Selector_2 (
        .reset(btn_reset),
        .btn(btn_inc2),
        .user_choice(user_choice2)
    );

	// Instantiate ripple_carry
    ripple_carry AdderSubtractor (
        .A(user_choice1),
        .B(user_choice2),
        .C(mode_select),
        .S(adder_output[3:0]),   // Lower 4 bits of the output
        .Carry(adder_output[4])  // Most significant bit of the output
    );

    // Instantiate output_splitter
    output_splitter Splitter (
        .Initial_A(adder_output[4]),  // Assuming 'adder_output' is 5 bits where bit 5 is 'Initial_A'
        .B(adder_output[3]),
        .C(adder_output[2]),
        .D(adder_output[1]),
        .E(adder_output[0]),
        .mode_select(mode_select),
        .I(splitter_output1),         // 'splitter_output1' replaces 'out1'
        .J(splitter_output2)          // 'splitter_output2' replaces 'out2'
    );

	// Instantiate first mux_2to1 (equals mux)
    mux_2to1 equals_mux_1 (
        .A(user_choice1),
        .B(splitter_output1),
        .S(equals_switch),
        .F(mux_output1)
    );

    // Instantiate second mux_2to1 (equals mux)
    mux_2to1 equals_mux_2 (
        .A(user_choice2),
        .B(splitter_output2),
        .S(equals_switch),
        .F(mux_output2)
    );

	// Instantiate third mux_2to1 (display mux)
    mux_2to1 display_mux (
        .A(mux_output1),
        .B(mux_output2),
        .S(anode_select_output),
        .F(mux_output3)
    );

	// Instantiate anode_selector
	anode_selector AnodeSelector (
        .clk(clk),
        .selector(anode_select_output)
    );

	// Instantiate seg7_4bit_1digit_decoder
	seg7_4bit_1digit_decoder Seg7decoder (
		.bin(mux_output3),
		.seg7(seg7_output)
	);
endmodule


`timescale 1ms / 1ms

module top_tb;

    // Testbench generated inputs for the top module
    reg clk;
    reg btn_inc1;
    reg btn_inc2;
    reg btn_reset;
    reg mode_select;
    reg equals_switch;

    // Testbench monitored outputs from the top module
    wire [6:0] seg7_output;

    // Instantiate Unit Under Test
    top UUT(
        .clk(clk),
        .btn_inc1(btn_inc1),
        .btn_inc2(btn_inc2),
        .btn_reset(btn_reset),
        .mode_select(mode_select),
        .equals_switch(equals_switch),
        .seg7_output(seg7_output)
    );

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk; // Generate a clock with a period of 5MS

    initial begin
        // Initialize inputs
        btn_inc1 = 0;
        btn_inc2 = 0;
        btn_reset = 0;
        mode_select = 0;   // Start with addition mode
        equals_switch = 0; // Start with displaying user_choice

        // VCD file generation
        $dumpfile("top_tb.vcd"); // Specify the VCD file name
        $dumpvars(0, top_tb);    // Record all signals in and below top_tb

        #50 // Give time to observe initial condition

        // Increment user_choice1 and user_choice2
        btn_inc1 = 1;
        btn_inc2 = 1; #10
        btn_inc1 = 0;
        btn_inc2 = 0; #50

        // Increment user_choice1 and user_choice2
        btn_inc1 = 1;
        btn_inc2 = 1; #10;
        btn_inc1 = 0;
        btn_inc2 = 0; #50

        // Increment user_choice1 and user_choice2
        btn_inc1 = 1;
        btn_inc2 = 1; #10;
        btn_inc1 = 0;
        btn_inc2 = 0; #50

        // Increment user_choice1 and user_choice2
        btn_inc1 = 1;
        btn_inc2 = 1; #10
        btn_inc1 = 0;
        btn_inc2 = 0; #50

        // Reset sequence
        btn_reset = 0; #10
        btn_reset = 1; #10
        btn_reset = 0; #20


        // TEST CASE: 4 + 9
        // INCREMENT TO 4
        btn_inc1 = 1; #10
        btn_inc1 = 0; #50

        btn_inc1 = 1; #10
        btn_inc1 = 0; #50
        
        btn_inc1 = 1; #10
        btn_inc1 = 0; #50
        
        btn_inc1 = 1; #10
        btn_inc1 = 0; #50

        // INCREMENT TO 9
        btn_inc2 = 1; #10
        btn_inc2 = 0; #50
        
        btn_inc2 = 1; #10
        btn_inc2 = 0; #50
        
        btn_inc2 = 1; #10
        btn_inc2 = 0; #50
        
        btn_inc2 = 1; #10
        btn_inc2 = 0; #50
        
        btn_inc2 = 1; #10
        btn_inc2 = 0; #50
        
        btn_inc2 = 1; #10
        btn_inc2 = 0; #50
        
        btn_inc2 = 1; #10
        btn_inc2 = 0; #50
        
        btn_inc2 = 1; #10
        btn_inc2 = 0; #50
        
        btn_inc2 = 1; #10
        btn_inc2 = 0; #50
        
        #90

        // DISPLAY OUTPUT
        equals_switch = 1; #100

        // DISPLAY INPUT
        equals_switch = 0; #100

        // TEST CASE 4 - 9
        // SUBTRACTION MODE
        mode_select = 1;

        // DISPLAY OUTPUT
        equals_switch = 1; #100

        // End simulation
        $finish;
    end

    // Monitor changes
    initial begin
        $monitor("Time = %t, seg7_output = %b", $time, seg7_output);
    end
endmodule
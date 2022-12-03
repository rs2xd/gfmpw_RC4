`default_nettype none
// update this to the name of your module
module wrapped_rc4(
`ifdef USE_POWER_PINS
    inout vdd,	// User area 1 1.8V supply
    inout vss,	// User area 1 digital ground
`endif
    // interface as user_proj_example.v
    input wire wb_clk_i,
    input wire wb_rst_i,

    // Logic Analyzer Signals
    // only provide first 32 bits to reduce wiring congestion

    input  wire [`MPRJ_IO_PADS-1:0] io_in,
    output wire [`MPRJ_IO_PADS-1:0] io_out,
    output wire [`MPRJ_IO_PADS-1:0] io_oeb,

);


    assign io_oeb[`MPRJ_IO_PADS-25:`MPRJ_IO_PADS-32] = {8{1'b1}}; //8 ones
    //assign io_oeb[`MPRJ_IO_PADS-17:`MPRJ_IO_PADS-24] = {8{1'b1}}; //8 ones
    assign io_oeb[`MPRJ_IO_PADS-1:`MPRJ_IO_PADS-9] = {16{1'b0}}; //16 zeros

    wire reset = ! wb_rst_i;

    rc4 rc4_1(
        .clk(wb_clk_i),
	.rst(wb_rst_i),
	.password_input(io_in[`MPRJ_IO_PADS-25:`MPRJ_IO_PADS-32]),
        .output_ready(io_out[`MPRJ_IO_PADS-1]),
        .K(io_out[`MPRJ_IO_PADS-2:`MPRJ_IO_PADS-9])
        );

endmodule


`define KEY_SIZE 8

module rc4(clk,rst,output_ready,password_input,K);

input clk; // Clock
input rst; // Reset
input [7:0] password_input; // Password input
output output_ready; // Output valid
output [7:0] K; // Output port


wire clk, rst; // clock, reset
reg output_ready;
wire [7:0] password_input;


/* RC4 PRGA */

// Key
reg [7:0] key[0:`KEY_SIZE-1];
// S array
reg [7:0] S[0:256];
reg [10:0] discardCount;

// Key-scheduling state
`define KSS_KEYREAD 4'h0
`define KSS_KEYSCHED1 4'h1
`define KSS_KEYSCHED2 4'h2
`define KSS_KEYSCHED3 4'h3
`define KSS_CRYPTO 	 4'h4
// Variable names from http://en.wikipedia.org/wiki/RC4
reg [3:0] KSState;
reg [7:0] i; // Counter
reg [7:0] j;
reg [7:0] K;

always @ (posedge clk)
	begin
	if (rst)
		begin
		i <= 8'b00000000;
		KSState <= `KSS_KEYREAD;
		output_ready <= 0;
		j <= 0; 
		end
	else
	case (KSState)	
		`KSS_KEYREAD:	begin // KSS_KEYREAD state: Read key from input
				if (i == `KEY_SIZE)
					begin
					KSState <= `KSS_KEYSCHED1;
					i<=8'b00000000;
					end
				else	begin
					i <= i+1;
					key[i] <= password_input;
					$display ("rc4: key[%d] = %08X",i,password_input);
					end
				end
/*
for i from 0 to 255
    S[i] := i
endfor
*/
		`KSS_KEYSCHED1:	begin // KSS_KEYSCHED1: Increment counter for S initialization
				S[i] <= i;
				if (i == 8'b11111111)
					begin
					KSState <= `KSS_KEYSCHED2;
					i <= 8'b00000000;
					end
				else	i <= i +1;
				end
/*		
j := 0
for i from 0 to 255
    j := (j + S[i] + key[i mod keylength]) mod 256
    swap values of S[i] and S[j]
endfor
*/
		`KSS_KEYSCHED2:	begin // KSS_KEYSCHED2: Initialize S array
				j <= (j + S[i] + key[i % `KEY_SIZE]);
				KSState <= `KSS_KEYSCHED3;
				end
		`KSS_KEYSCHED3:	begin // KSS_KEYSCHED3: S array permutation
				S[i]<=S[j];
				S[j]<=S[i];
				if (i == 8'b11111111)
					begin
					KSState <= `KSS_CRYPTO;
					i <= 8'b00000001;
					j <= S[1];
					discardCount <= 11'h0;
					output_ready <= 0; // K not valid yet
					end
				else	begin
					i <= i + 1;
					KSState <= `KSS_KEYSCHED2;
					end
				end
/*				
i := 0
j := 0
while GeneratingOutput:
    i := (i + 1) mod 256
    j := (j + S[i]) mod 256
    swap values of S[i] and S[j]
    K := S[(S[i] + S[j]) mod 256]
    output K
endwhile
*/
		`KSS_CRYPTO: begin
				S[i] <= S[j];
				S[j] <= S[i]; // We can do this because of verilog.
				K <= S[ S[i]+S[j] ];
				if (discardCount<11'h600) // discard first 1536 values / RFC 4345
					discardCount<=discardCount+1;
				else	output_ready <= 1; // Valid K at output
				i <= i+1;
				// Here is the secret of 1-clock: we develop all possible values of j in the future
				if (j==i+1) 
   				     j <= (j + S[i]);
				else 
					if (i==255) j <= (j + S[0]);
						else j <= (j + S[i+1]);
				//$display ("rc4: output = %08X",K, );
				end
		default:	begin
				end
	endcase
	end

endmodule

`default_nettype wire


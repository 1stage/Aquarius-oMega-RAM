`timescale 1ns / 1ps

/*
Aquarius oMega Paged RAM in Verilog
by Sean P. Harrington

This code is designed to run on the CPLD for the Aquarius oMega RAM expander.
The expander offers 3MB of paged RAM, 16KB @ 64 pages, banked in these ranges:

   -  LO RAM $4000 - $7FFF
   - MID RAM $8000 - $BFFF
   -  HI RAM $C000 - $FFFF

If a cartridge is inserted, HI RAM is disabled to allow the cartridge code
to run, uninterfered. 

The active page for each bank of RAM is set by writing to IO address $E7. The
upper 2 bits set the bank, and the lower 6 bits set the page:

   - not used         $00 - $3F
   - set  LO RAM page $40 - $7F
   - set MID RAM page $80 - $BF
   - set  HI RAM page $C0 - $FF

Version History
19 SEP 2021  v0.4   - Corrected HI RAM toggling???
24 AUG 2021  v0.3   - Added Aquarius WR signal to the IORQ logic
23 AUG 2021  v0.2   - Added HI RAM v Cartridge conflict logic.
18 AUG 2021  v0.1   - Initial version

*/

module paged_RAM (
	inout [7:0]  aq_data,       // in/out to  Aquarius Data Bus
	input [13:0] aq_addr_LO,    // input from Aquarius Address Bus A00-A13
	input [1:0]  aq_addr_HI,    // input from Aquarius Address Bus A14-A15
	input aq_mreq,              // input from Aquarous MREQ signal
	input aq_iorq,              // input from Aquarius IORQ signal
	input aq_wr,                // input from Aquarius WR signal
	output a_ce,                // output to  LO RAM's CE pin
	output b_ce,                // output to MID RAM's CE pin
	output c_ce,                // output to  HI RAM's CE pin
	output reg [5:0] x_page     // output to RAM's Address Bus A14-A19
);
	
	reg hi_RAM_enable = 0;      // Disable HI RAM by default
	
	assign a_ce = !( aq_addr_HI[0] & !aq_addr_HI[1] & !aq_mreq);
	assign b_ce = !(!aq_addr_HI[0] &  aq_addr_HI[1] & !aq_mreq);
	assign c_ce = !( aq_addr_HI[0] &  aq_addr_HI[1] & !aq_mreq) & hi_RAM_enable;

	reg [5:0] a_page = 0;       // Starting page for  LO RAM
	reg [5:0] b_page = 0;       // Starting page for MID RAM
	reg [5:0] c_page = 0;       // Starting page for  HI RAM
    
	assign io_flag = (aq_addr_LO[7:0] == 8'he7); // Set if IO address is $e7
	assign iowr    = aq_iorq | aq_wr;            // Set IOWR inactive (HI) if either IORQ or WR are inactive (HI)
  
	// Change the master RAM page when LO, MID, or HI RAM's CE pins go low
	always @ (negedge a_ce or negedge b_ce or negedge c_ce)
		begin
			if (!a_ce)
				x_page <= a_page;
			else if (!b_ce)
				x_page <= b_page;
			else if (!c_ce & hi_RAM_enable)   // Only if HI RAM is enabled
				x_page <= c_page;
			else
				x_page <= 0;
		end
		
	// Change the stored LO, MID, or HI RAM active page when IORQ 
	always @ (negedge iowr)
		begin
			if      ( aq_data[6] & !aq_data[7] & io_flag)
				a_page <= aq_data[5:0];
			else if (!aq_data[6] &  aq_data[7] & io_flag)
				b_page <= aq_data[5:0];
			else if ( aq_data[6] &  aq_data[7] & io_flag) 
				c_page <= aq_data[5:0];
				hi_RAM_enable <= 1;       // Enable HI RAM
		end
		  
endmodule

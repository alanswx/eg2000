//============================================================================
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [45:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,

`ifdef USE_FB
	// Use framebuffer in DDRAM (USE_FB=1 in qsf)
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

`ifdef USE_DDRAM
	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,
`endif

`ifdef USE_SDRAM
	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,
`endif

`ifdef DUAL_SDRAM
	//Secondary SDRAM
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

///////// Default values for ports not used in this core /////////

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;  

assign VGA_SL = 0;
assign VGA_F1 = 0;
assign VGA_SCALER = 0;

assign AUDIO_S = 0;
assign AUDIO_MIX = 0;

assign LED_DISK = 0;
assign LED_POWER = 0;
assign BUTTONS = 0;

//////////////////////////////////////////////////////////////////


`include "build_id.v" 
localparam CONF_STR = {
	"eg2000;;",
	"-;",
	"O89,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
   "OAC,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%;",
	"OFG,Scale,Normal,V-Integer,Narrower HV-Integer,Wider HV-Integer;",
   "-;",
	"T0,Reset;",
	"R0,Reset and close OSD;",
	"V,v",`BUILD_DATE 
};


wire [21:0] gamma_bus;
wire forced_scandoubler;
wire  [1:0] buttons;
wire [31:0] status;
wire [10:0] ps2_key;
wire  [1:0] ps2;


// PS2DIV : la mitad del divisor que necesitas para dividir el clk_sys que le das al hpio, para que te de entre 10Khz y 16Kzh
hps_io #(.STRLEN($size(CONF_STR)>>3), .PS2DIV(2500)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),
	.EXT_BUS(),

	.conf_str(CONF_STR),
	.forced_scandoubler(forced_scandoubler),

	.buttons(buttons),
	.status(status),
	.status_menumask({status[5]}),
	.ps2_kbd_clk_out(ps2[0]),
   .ps2_kbd_data_out(ps2[1])
  );

///////////////////////   CLOCKS   ///////////////////////////////

wire clk_sys;
pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_sys)
);

wire reset = RESET | status[0] | buttons[1];

//////////////////////////////////////////////////////////////////


wire HBlank;
wire HSync;
wire VBlank;
wire VSync;
wire ce_pix;

wire [2:0] R;
wire [2:0] G;
wire [2:0] B;

wire led;

//eg2000 eg2000
//(
//	.clock    	(clk_sys),
//	.resetOsd 	(reset),
//	.ce_pix   	(ce_pix),
//   .led      	(led),
//	.HBlank     (HBlank),
//	.VBlank     (VBlank),
//   .rgb 			({R,G,B}),
//	.ps2 			(ps2),
//	.ear			(~tape_in),
//	.audio_l 	(AUDIO_L),
//	.audio_r    (AUDIO_R),
//	.HSync      (HSync),
//	.VSync      (VSync),
//);

reg[7:0] rs;
wire power = rs[7] & ~status[0] & ~RESET & ~buttons[1];
always @(posedge clk_sys) if(!power) rs <= rs+1'd1;

wire[3:0] color;

glue Glue
(
	.clock  (clk_sys  ),
	.power  (power  ),
	.hsync  (HSync  ),
	.vsync  (VSync  ),
	.vblank (VBlank ),
	.hblank (HBlank ),
	.ce_pix (ce_pix ),
	.pixel  (pixel  ),
	.color  (color  ),
	.tape   (~tape_in),
	.audio_l(AUDIO_L ),
	.audio_r(AUDIO_R ),
	.ps2    (ps2     ),
	.ramCk  (SDRAM_CLK),
	.ramCe  (SDRAM_CKE),
	.ramCs  (SDRAM_nCS),
	.ramWe  (SDRAM_nWE),
	.ramRas (SDRAM_nRAS),
	.ramCas (SDRAM_nCAS),
	.ramDqm ({SDRAM_DQMH,SDRAM_DQML}),
	.ramDQ  (SDRAM_DQ),
	.ramBA  (SDRAM_BA),
	.ramA   (SDRAM_A )
);


reg[17:0] palette[15:0];
initial begin
	palette[15] = 18'b111000_111000_111000; // FF FF FF // 16 // white
	palette[14] = 18'b100000_001000_111000; // 98 20 FF //  8 // magenta
	palette[13] = 18'b001000_110000_100000; // 1F C4 8C // 14 // turquise
	palette[12] = 18'b100000_100000_100000; // 8C 8C 8C // 13 // grey
	palette[11] = 18'b100000_011000_111000; // 8A 67 FF // 12 // violet
	palette[10] = 18'b110000_010000_111000; // C7 4E FF // 15 // pink
	palette[ 9] = 18'b101000_110000_111000; // BC DF FF //  9 // light blue
	palette[ 8] = 18'b001000_010000_111000; // 2F 53 FF //  8 // blue
	palette[ 7] = 18'b110000_111000_001000; // EA FF 27 // 11 // yellow/green
	palette[ 6] = 18'b111000_011000_001000; // EB 6F 2B //  5 // orange
	palette[ 5] = 18'b101000_111000_010000; // AB FF 4A //  2 // green
	palette[ 4] = 18'b111000_111000_001000; // FF F2 3D //  4 // yellow
	palette[ 3] = 18'b111000_111000_111000; // EA EA EA //  1 // light grey
	palette[ 2] = 18'b110000_001000_010000; // CB 26 5E //  3 // red
	palette[ 1] = 18'b011000_111000_111000; // 7C FF EA //  7 // cyan
	palette[ 0] = 18'b010000_010000_010000; // 5E 5E 5E // 10 // dark grey
end

wire[17:0] rgbQ = pixel ? palette[color] : 1'd0;

assign CLK_VIDEO = clk_sys;
wire ce_pix_out;
wire scandoubler = scale || forced_scandoubler;
wire [2:0] scale = status[12:10];


video_mixer #(.GAMMA(1)) video_mixer
(
        .*,
		  .R         ({rgbQ[17:12],2'b0}),
	     .G         ({rgbQ[11: 6],2'b0}),
	     .B         ({rgbQ[ 5: 0],2'b0}),

        .hq2x      (scale==1)
);


wire [1:0] ar = status[9:8];

video_freak video_freak
(
	.*,
	.VGA_DE_IN     (VGA_DE),
	.VGA_DE        (),

	.ARX           ((!ar) ? 12'd4 : (ar - 1'd1)),
	.ARY           ((!ar) ? 12'd3 : 12'd0),
	.CROP_SIZE     (0),
	.CROP_OFF      (0),
	.SCALE         (status[16:15])
);
assign LED_USER    = led;


//Mister TapeIn

wire tape_in;
wire tape_adc, tape_adc_act;

assign tape_in = tape_adc_act & tape_adc;


ltc2308_tape  tape
(
  .clk		(CLK_50M), 
  .ADC_BUS	(ADC_BUS),
  .dout		(tape_adc),
  .active	(tape_adc_act)
);

endmodule
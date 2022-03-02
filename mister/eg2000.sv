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
	inout  [48:0] HPS_BUS,

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
	output        HDMI_FREEZE,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM (USE_FB=1 in qsf)
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp	 signal vdg_hs_n        : std_logic;
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

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
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

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
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

assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;



assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;  

assign VGA_SL = (scale[2]==1'b1)?2'd0:scale[1:0];
assign HDMI_FREEZE = 0;

assign VGA_F1 = 0;
assign VGA_SCALER = 0;

assign AUDIO_S = 0;
assign AUDIO_MIX = 0;

//assign LED_DISK = 0;
assign LED_POWER = 0;
assign BUTTONS = 0;

//////////////////////////////////////////////////////////////////


`include "build_id.v" 
localparam CONF_STR = {
	"eg2000;;",
	"-;",
	"O89,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
   "OAC,Scandoubler Fx,None,CRT 25%,CRT 50%,CRT 75%,HQ2x;",
	"OFG,Scale,Normal,V-Integer,Narrower HV-Integer,Wider HV-Integer;",
   "-;",
	"OE,Tape Input,File,ADC;",
	"H0F2,CAS,Load Cassette;",
	"H0TH,Stop & Rewind;",
	"H0T2,Tape Play/Pause;",
	"OD,Monitor Tape Sound,No,Yes;",
	"-;",
	"T0,Reset;",
	"R0,Reset and close OSD;",
	"V,v",`BUILD_DATE 
};


wire        forced_scandoubler;
wire        direct_video;

wire [21:0] gamma_bus;


wire  [1:0] buttons;
wire [31:0] status;
wire  [1:0] ps2;

wire        ioctl_download;
wire  [7:0] ioctl_index;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;


// PS2DIV : la mitad del divisor que necesitas para dividir el clk_sys que le das al hpio, para que te de entre 10Khz y 16Kzh
hps_io #(.CONF_STR(CONF_STR), .PS2DIV(2500)) hps_io
(
	.clk_sys		(clk_sys),
	.HPS_BUS		(HPS_BUS),

	.buttons(buttons),
	.status(status),
	.forced_scandoubler(forced_scandoubler),
	.gamma_bus(gamma_bus),
	.direct_video(direct_video),
	
	.status_menumask({status[14]}),
	
	.ioctl_download(ioctl_download),
	.ioctl_index(ioctl_index),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),

	.ps2_kbd_clk_out (ps2[0]),
   .ps2_kbd_data_out(ps2[1])
  );

///////////////////////   CLOCKS   ///////////////////////////////

wire clk_sys;
wire pll_locked;

pll pll
(
	.refclk   (CLK_50M),
	.rst      (0),
	.outclk_0 (clk_sys),
	.locked   (pll_locked)
);



//////////////////////////////////////////////////////////////////


wire HBlank;
wire HSync;
wire VBlank;
wire VSync;
wire ce_pix;
wire led;
wire pixel;

reg[5:0] rs;
wire power = rs[5] & ~status[0] & ~RESET & ~buttons[1];
always @(posedge clk_sys) if(!power) rs <= rs+1'd1;

wire[3:0] color;

assign AUDIO_L = AUDIO_R;
assign AUDIO_R = sound_pad;
wire [15:0] sound;
wire [15:0] sound_pad =  {sound[15:11], sound[10] ^ (status[13] ? (status[14] ? adc_cassette_bit : casdout) : 1'b0), sound[9:0]};


glue Glue
(
	.clock  (clk_sys),
	.power  (power  ),
	.hsync  (HSync),
	.vsync  (VSync),
	.hblank  (HBlank),
	.vblank  (VBlank),

	.ce_pix (ce_pix ),
	.pixel  (pixel  ),
	.color  (color  ),
	.crtcDe (crtcDe_tmp),
	.tape   (status[14]?adc_cassette_bit:casdout ),
	.audio_l(sound),
	.audio_r(),
	.led    (led    ),
	.ps2    (ps2    )
);


reg[17:0] palette[15:0];
initial begin
	palette[15] = 18'b111111_111111_111111; // FF FF FF // 16 // white
	palette[14] = 18'b100110_001000_111111; // 98 20 FF //  8 // magenta
	palette[13] = 18'b000111_110001_100011; // 1F C4 8C // 14 // turquise
	palette[12] = 18'b100011_100011_100011; // 8C 8C 8C // 13 // grey
	palette[11] = 18'b100010_011001_111111; // 8A 67 FF // 12 // violet
	palette[10] = 18'b110001_010011_111111; // C7 4E FF // 15 // pink
	palette[ 9] = 18'b101111_110111_111111; // BC DF FF //  9 // light blue
	palette[ 8] = 18'b001011_010100_111111; // 2F 53 FF //  8 // blue
	palette[ 7] = 18'b111010_111111_001001; // EA FF 27 // 11 // yellow/green
	palette[ 6] = 18'b111010_011011_001010; // EB 6F 2B //  5 // orange
	palette[ 5] = 18'b101010_111111_010010; // AB FF 4A //  2 // green
	palette[ 4] = 18'b111111_111100_001111; // FF F2 3D //  4 // yellow
	palette[ 3] = 18'b111010_111010_111010; // EA EA EA //  1 // light grey
	palette[ 2] = 18'b110010_001001_010111; // CB 26 5E //  3 // red
	palette[ 1] = 18'b011011_111111_111010; // 7C FF EA //  7 // cyan
	palette[ 0] = 18'b010111_010111_010111; // 5E 5E 5E // 10 // dark grey
end

wire[17:0] rgbQ = pixel ? palette[color] : 1'd0;

assign CLK_VIDEO = clk_sys;

wire ce_pix_out;
wire scandoubler = scale || forced_scandoubler;
wire [2:0] scale = status[12:10];
wire crtcDe_tmp;

// YOM Sin Video_Mixer ni Video_Freak
//assign CE_PIXEL = ce_pix;
//assign VGA_R = {rgbQ[17:12],2'b0};
//assign VGA_G = {rgbQ[11: 6],2'b0};
//assign VGA_B = {rgbQ[ 5: 0],2'b0};
//assign VGA_VS = VSync;
//assign VGA_HS = HSync;
//assign VGA_DE = crtcDe_tmp;//~(VBlank | HBlank);
//
//assign VIDEO_ARX = 4;
//assign VIDEO_ARY = 3;

// YOM Sin Video_Freak pero si con video_mixer
//assign VIDEO_ARX = 4;
//assign VIDEO_ARY = 3;
//assign VGA_DE = crtcDe_tmp;

video_mixer #(.LINE_LENGTH(640)) video_mixer
(
	.CLK_VIDEO		(CLK_VIDEO),
	.CE_PIXEL		(CE_PIXEL),
	.ce_pix			(ce_pix),
	.scandoubler	(scandoubler),
	.gamma_bus		(gamma_bus),
	.HSync			(HSync),
	.VSync			(VSync),
	.HBlank			(HBlank),
	.VBlank			(VBlank),

	// video output signals
	.VGA_R			(VGA_R), //output reg [7:0] VGA_R,
	.VGA_G			(VGA_G), //output reg [7:0] VGA_G,
	.VGA_B			(VGA_B), //output reg [7:0] VGA_B,
	.VGA_VS			(VGA_VS), //output reg       VGA_VS,
	.VGA_HS			(VGA_HS), //output reg       VGA_HS,		
	.VGA_DE			(VGA_DE), //output reg       VGA_DE,
		
	.R         		({rgbQ[17:12],2'b0}),
   .G         		({rgbQ[11: 6],2'b0}),
   .B         		({rgbQ[ 5: 0],2'b0}),
	.hq2x      		(scale[2])
);


wire [1:0] ar = status[9:8];

video_freak video_freak
(
	.CLK_VIDEO		(CLK_VIDEO),
	.CE_PIXEL		(CE_PIXEL),
	.VGA_VS			(VGA_VS),
	.HDMI_WIDTH		(HDMI_WIDTH), //input      [11:0] HDMI_WIDTH,
	.HDMI_HEIGHT	(HDMI_HEIGHT), //input      [11:0] HDMI_HEIGHT,
	.VIDEO_ARX		(VIDEO_ARX), //output reg [12:0] VIDEO_ARX,
	.VIDEO_ARY		(VIDEO_ARY), //output reg [12:0] VIDEO_ARY,
	
	.VGA_DE_IN     (VGA_DE),
	.VGA_DE        (),
	.ARX           ((!ar) ? 12'd4 : (ar - 1'd1)),
	.ARY           ((!ar) ? 12'd3 : 12'd0),
	.CROP_SIZE     (0),
	.CROP_OFF      (0),
	.SCALE         (status[16:15])
);


/////////////////////// ADC Module  //////////////////////////////


wire [11:0] adc_data;
wire        adc_sync;
reg [11:0] adc_value;
reg adc_sync_d;

integer ii=0;
reg [11:0] adc_val[0:511];
reg [21:0] adc_total = 0;
reg [11:0] adc_avg;

reg adc_cassette_bit;


// interface to ADC via framework
//
ltc2308 #(1, 48000, 50000000) adc_input		// mono, ADC_RATE = 48000, CLK_RATE = 50000000
(
	.reset(~power),
	.clk(CLK_50M),

	.ADC_BUS(ADC_BUS),
	.dout(adc_data),
	.dout_sync(adc_sync)
);

// when data arrives:
//		- latch it in adc_value
//		- keep track of a running average across 512 samples
//
//		-> this average acts as a high-pass filter above roughly 100 Hz while retaining
//		 	while retaining very high frequency response, for possible future fast-load techniques
//
always @(posedge CLK_50M) begin

	adc_sync_d<=adc_sync;
	if(adc_sync_d ^ adc_sync) begin
		adc_value <= adc_data;					// latch in current value, adc_Value
		
		adc_val[0] <= adc_value;				
		adc_total  <= adc_total - adc_val[511] + adc_value;

		for (ii=0; ii<511; ii=ii+1)
			adc_val[ii+1] <= adc_val[ii];
			
		adc_avg <= adc_total[20:9];			// update average value every fetch
		
		if (adc_value < (adc_avg - 100))		// flip the cassette bit if > 0.1V from average
			adc_cassette_bit <= 1;				// note that original CoCo reversed polarity

		if (adc_value > (adc_avg + 100))
			adc_cassette_bit <= 0;
		
	end
end

assign LED_USER = adc_cassette_bit ;




wire casdout;
wire cas_relay;



wire [24:0] sdram_addr;
wire [7:0] sdram_data;
wire sdram_rd;
wire load_tape = ioctl_index[5:0] == 2;
reg [24:0] tape_end;

sdram sdram
(
	.*,
	.init(~pll_locked),
	.clk(clk_sys),
	.addr(ioctl_download ? ioctl_addr : sdram_addr),
	.wtbt(0),
	.dout(sdram_data),
	.din(ioctl_dout),
	.rd(sdram_rd),
	.we(ioctl_wr & load_tape),
	.ready()
);



always @(posedge clk_sys) begin
 if (load_tape) tape_end <= ioctl_addr;
end

cassette cassette(
  .clk(clk_sys),

   .play(status[2]),
   .rewind(status[17] | (load_tape&ioctl_download)),
  .sdram_addr(sdram_addr),
  .sdram_data(sdram_data),
  .sdram_rd(sdram_rd),

  .tape_end(tape_end),
  .data(casdout)
//   .status(tape_status)
);


//Mister TapeIn
/*
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

assign LED_USER    = ~tape_in;
*/
endmodule

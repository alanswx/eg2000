//-------------------------------------------------------------------------------------------------
module glue
//-------------------------------------------------------------------------------------------------
(
	input  wire       clock,
	input  wire       power,

	output wire       hsync,
	output wire       vsync,
	output wire       ce_pix,

	output wire       hblank,
	output wire       vblank,

	output wire       pixel,
	output wire[ 3:0] color,
	output wire			crtcDe,

	input  wire       tape,
`ifdef USE_DAC
	output wire       sound,
`else
   output wire [15:0] audio_l,
   output wire [15:0] audio_r,
`endif
	input  wire[ 1:0] ps2,
	output wire       led

);
//-------------------------------------------------------------------------------------------------

reg[4:0] ce;
always @(negedge clock) ce <= ce+1'd1;



assign ce_pix = pe8M8;

wire pe8M8 = ~ce[0] &  ce[1];
wire ne8M8 = ~ce[0] & ~ce[1];

wire ne4M4 = ~ce[0] & ~ce[1] & ~ce[2];

wire pe2M2 = ~ce[0] & ~ce[1] & ~ce[2] &  ce[3];
wire ne2M2 = ~ce[0] & ~ce[1] & ~ce[2] & ~ce[3];

wire pe1M1 = ~ce[0] & ~ce[1] & ~ce[2] & ~ce[3] &  ce[4];

//-------------------------------------------------------------------------------------------------

wire ioF8 = !(!iorq && a[7:0] == 8'hF8); // psg addr
wire ioF9 = !(!iorq && a[7:0] == 8'hF9); // psg data

wire ioFA = !(!iorq && a[7:0] == 8'hFA); // crtc addr
wire ioFB = !(!iorq && a[7:0] == 8'hFB); // crtc data

wire ioFF = !(!iorq && a[7:0] == 8'hFF);

//-------------------------------------------------------------------------------------------------

wire reset = power & kreset;

assign led = reset;
wire[ 7:0] d;
wire[ 7:0] q;
wire[15:0] a;

wire rfsh, mreq, iorq, rd, wr;

cpu Cpu
(
	.clock  (clock  ),
	.cep    (pe2M2  ),
	.cen    (ne2M2  ),
	.reset  (reset  ),
	.rfsh   (rfsh   ),
	.mreq   (mreq   ),
	.iorq   (iorq   ),
	.rd     (rd     ),
	.wr     (wr     ),
	.nmi    (nmi    ),
	.d      (d      ),
	.q      (q      ),
	.a      (a      )
);

//-------------------------------------------------------------------------------------------------

wire crtcCs = !(!ioFA || !ioFB);
wire crtcRs = a[0];
wire crtcRw = wr;

wire[ 7:0] crtcQ;

wire[13:0] crtcMa;
wire[ 4:0] crtcRa;

wire cursor;

UM6845R Crtc
(
	.TYPE   (1'b0   ),
	.CLOCK  (clock  ),
	.CLKEN  (pe1M1  ),
	.nRESET (reset  ),
	.ENABLE (1'b1   ),
	.nCS    (crtcCs ),
	.R_nW   (crtcRw ),
	.RS     (crtcRs ),
	.DI     (q      ),
	.DO     (crtcQ  ),
	.VSYNC  (vsync  ),
	.HSYNC  (hsync  ),
	.HBLANK (hblank ),
	.VBLANK (vblank ),

	.DE     (crtcDe ),
	.FIELD  (       ),
	.CURSOR (cursor ),
	.MA     (crtcMa ),
	.RA     (crtcRa )
);

reg[1:0] cur;
always @(posedge clock) if(pe1M1) cur <= { cur[0], cursor };

//-------------------------------------------------------------------------------------------------

wire bdir = (!wr && !ioF8) || (!wr && !ioF9);
wire bc1  = (!wr && !ioF8) || (!rd && !ioF9);

wire[7:0] psgA;
wire[7:0] psgB;
wire[7:0] psgC;
wire[7:0] psgQ;

jt49_bus Psg
(
	.clk    (clock  ),
	.clk_en (pe2M2  ),
	.rst_n  (reset  ),
	.bdir   (bdir   ),
	.bc1    (bc1    ),
	.din    (q      ),
	.dout   (psgQ   ),
	.A      (psgA   ),
	.B      (psgB   ),
	.C      (psgC   ),
	.sel    (1'b0   )
);


//-------------------------------------------------------------------------------------------------



wire[9:0] dacD = { 2'b00, psgA } + { 2'b00, psgB } + { 2'b00, psgC };

`ifdef USE_DAC
dac #(.MSBI(9)) Dac
(
	.clock  (clock  ),
	.reset  (reset  ),
	.d      (dacD   ),
	.q      (sound  )
);
`else
 assign audio_l = {dacD,6'b0};
 assign audio_r = audio_l;
`endif

//-------------------------------------------------------------------------------------------------

wire[7:0] keyQ;
wire[7:0] keyA = a[7:0];
wire nmi,boot,kreset;


`ifdef ZX1
keyboard Keyboard
`else
keyboard #(.BOOT(8'h0A), .RESET(8'h78)) Keyboard //Boot(F8) - Reset(F11)
`endif
(
	.clock  (clock  ),
	.ce     (pe8M8  ),
	.ps2    (ps2    ),
	.nmi    (nmi    ),
	.boot   (boot   ),
	.reset  (kreset ),
	.q      (keyQ   ),
	.a      (keyA   )
);

//-------------------------------------------------------------------------------------------------

reg mode, c, b;
always @(posedge clock) if(pe2M2) if(!ioFF && !wr) { mode, c, b } <= q[5:3];

//-------------------------------------------------------------------------------------------------

wire[13:0] vma = crtcMa;
wire[ 2:0] vra = crtcRa[2:0];

wire[ 7:0] memQ;
wire ven;

memory Memory
(
	.clock  (clock  ),
	.hsync  (hsync  ),
	.vcep   (pe8M8  ),
	.vcen   (ne8M8  ),
	.hrce   (ne4M4  ),
	.vma    (vma    ),
	.vra    (vra    ),
	.b      (b      ),
	.c      (c      ),
	.mode   (mode   ),
	.ven    (ven    ),
	.color  (color  ),
	.ce     (pe2M2  ),
	.rfsh   (rfsh   ),
	.mreq   (mreq   ),
	.rd     (rd     ),
	.wr     (wr     ),
	.d      (q      ),
	.q      (memQ   ),
	.a      (a      ),
	.keyQ   (keyQ   )

);

assign pixel = (ven || cur[1]) && crtcDe;

//-------------------------------------------------------------------------------------------------

assign d
	= !mreq ? memQ
	: !ioF9 ? psgQ
	: !ioFB ? crtcQ
	: !ioFF ? { 7'd0, tape }
	: 8'hFF;

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------

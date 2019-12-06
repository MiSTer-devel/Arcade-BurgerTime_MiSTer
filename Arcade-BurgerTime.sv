//============================================================================
//  Arcade: Burger Time
//
//  Port to MiSTer
//  Copyright (C) 2017 Sorgelig
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
	output        VGA_CLK,

	//Multiple resolutions are supported using different VGA_CE rates.
	//Must be based on CLK_VIDEO
	output        VGA_CE,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,

	//Base video clock. Usually equals to CLK_SYS.
	output        HDMI_CLK,

	//Multiple resolutions are supported using different HDMI_CE rates.
	//Must be based on CLK_VIDEO
	output        HDMI_CE,

	output  [7:0] HDMI_R,
	output  [7:0] HDMI_G,
	output  [7:0] HDMI_B,
	output        HDMI_HS,
	output        HDMI_VS,
	output        HDMI_DE,   // = ~(VBlank | HBlank)
	output  [1:0] HDMI_SL,   // scanlines fx

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	output  [7:0] HDMI_ARX,
	output  [7:0] HDMI_ARY,

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	
	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT
	
	
);

assign VGA_F1    = 0;
assign USER_OUT  = '1;
assign LED_USER  = ioctl_download;
assign LED_DISK  = 0;
assign LED_POWER = 0;

assign HDMI_ARX = status[1] ? 8'd16 : status[2] ? 8'd4 : 8'd3;
assign HDMI_ARY = status[1] ? 8'd9  : status[2] ? 8'd3 : 8'd4;

`include "build_id.v" 
localparam CONF_STR = {
	"A.BTIME;;",
	"F,rom;", // allow loading of alternate ROMs
	"-;",
	"O1,Aspect Ratio,Original,Wide;",
	"O2,Orientation,Vert,Horz;",
	"O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"-;",
	"O8,Lives,3,5;",
	"O9A,Bonus,10k,15k,20k,30k;",
	"OB,Enemies,4,6;",
	"OF,End of Level Pepper,No,Yes;",	
	"OC,Cabinet,Upright,Cocktail;",	
	"OD,Hatch,Off,On;",	
	"OE,Test,Off,On;",	
	"-;",
	"R0,Reset;",
	"J1,Fire,Start 1P,Start 2P;",
	"V,v",`BUILD_DATE
};

/*
-- dip_sw1    -- unkown/cocktail/hatch/test/coinage_b[2]/coinage_a[2]
-- dip_sw2    -- off/off/off/eol pepper/enemies/bonus[2]/lives

dip_sw1 <= "00111111";  
dip_sw2 <= "11101110";
*/
wire [7:0] m_dip_sw1={1'b0,status[12],~status[13],~status[14],4'b1111};
wire [7:0] m_dip_sw2={3'b111,~status[15],~status[11],~status[10:9],~status[8]};

////////////////////   CLOCKS   ///////////////////

wire clk_sys, clk_24,clk_48;
wire pll_locked;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_sys),//12mhz
	.outclk_1(clk_24),
	.outclk_2(clk_48),
	.locked(pll_locked)
);

///////////////////////////////////////////////////

wire [31:0] status;
wire  [1:0] buttons;
wire        forced_scandoubler;

wire        ioctl_download;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;

wire [10:0] ps2_key;

wire [15:0] joystick_0, joystick_1;
wire [15:0] joy = joystick_0 | joystick_1;

wire [21:0] gamma_bus;


hps_io #(.STRLEN($size(CONF_STR)>>3)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.conf_str(CONF_STR),

	.buttons(buttons),
	.status(status),
	.forced_scandoubler(forced_scandoubler),
	.gamma_bus(gamma_bus),

	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),

	.joystick_0(joystick_0),
	.joystick_1(joystick_1),
	.ps2_key(ps2_key)
);

wire       pressed = ps2_key[9];

always @(posedge clk_sys) begin
	reg old_state;
	old_state <= ps2_key[10];
	
	if(old_state != ps2_key[10]) begin
		casex(ps2_key[8:0])
			9'hX75: btn_up          <= pressed; // up
			9'hX72: btn_down        <= pressed; // down
			9'hX6B: btn_left        <= pressed; // left
			9'hX74: btn_right       <= pressed; // right
			9'h029: btn_fire        <= pressed; // space
			9'hX14: btn_fire        <= pressed; // ctrl

			9'h005: btn_one_player  <= pressed; // F1
			9'h006: btn_two_players <= pressed; // F2
			// JPAC/IPAC/MAME Style Codes

			'h016: btn_start_1     <= pressed; // 1
			'h01E: btn_start_2     <= pressed; // 2
			'h02E: btn_coin_1      <= pressed; // 5
			'h036: btn_coin_2      <= pressed; // 6
			'h02D: btn_up_2        <= pressed; // R
			'h02B: btn_down_2      <= pressed; // F
			'h023: btn_left_2      <= pressed; // D
			'h034: btn_right_2     <= pressed; // G
			'h01C: btn_fire_2      <= pressed; // A
			'h02C: btn_test        <= pressed; // T
		endcase
	end
end

reg btn_up    = 0;
reg btn_down  = 0;
reg btn_right = 0;
reg btn_left  = 0;
reg btn_fire  = 0;
reg btn_one_player  = 0;
reg btn_two_players = 0;

reg btn_start_1=0;
reg btn_start_2=0;
reg btn_coin_1=0;
reg btn_coin_2=0;
reg btn_up_2=0;
reg btn_down_2=0;
reg btn_left_2=0;
reg btn_right_2=0;
reg btn_fire_2=0;
reg btn_test=0;

wire m_up     = status[2] ? btn_left  | joy[1] : btn_up    | joy[3];
wire m_down   = status[2] ? btn_right | joy[0] : btn_down  | joy[2];
wire m_left   = status[2] ? btn_down  | joy[2] : btn_left  | joy[1];
wire m_right  = status[2] ? btn_up    | joy[3] : btn_right | joy[0];
wire m_fire   = btn_fire | joy[4];

wire m_up_2     = status[2] ? btn_left_2  | joy[1] : btn_up_2    | joy[3];
wire m_down_2   = status[2] ? btn_right_2 | joy[0] : btn_down_2  | joy[2];
wire m_left_2   = status[2] ? btn_down_2  | joy[2] : btn_left_2  | joy[1];
wire m_right_2  = status[2] ? btn_up_2    | joy[3] : btn_right_2 | joy[0];
wire m_fire_2  = btn_fire_2|joy[4];


wire m_start1 = btn_one_player  | joy[5];
wire m_start2 = btn_two_players | joy[6];
wire m_coin   = m_start1 | m_start2;

wire hblank, vblank;
//wire ce_vid = clk_sys;
wire hs, vs;
wire [2:0] r,g;
wire [1:0] b;


reg ce_pix;
always @(posedge clk_48) begin
        reg old_clk;

        old_clk <= clk_sys;
        ce_pix <= old_clk & ~clk_sys;
end

//arcade_rotate_fx #(506,240,8,0) arcade_video
arcade_rotate_fx #(253,240,8,0) arcade_video
//arcade_rotate_fx #(524,240,8,0) arcade_video
(
        .*,

        .clk_video(clk_48),
        .ce_pix(ce_vid),

        .RGB_in({r,g,b}),
        .HBlank(hblank),
        .VBlank(vblank),
        .HSync(hs),
        .VSync(vs),

        .fx(status[5:3]),
        .no_rotate(status[2])
);
//screen_rotate #(253,240,8) screen_rotate

wire [10:0] audio;
assign AUDIO_L = {audio, 5'b00000};
assign AUDIO_R = AUDIO_L;
assign AUDIO_S = 0;

/*
reg initReset_n = 0;
always @(posedge clk_sys) begin
	reg old_download;
	old_download <= ioctl_download;
	if(old_download & ~ioctl_download) initReset_n <= 1;
end
*/

burger_time burger_time
(
	.clock_12(clk_sys),
	.reset(RESET | status[0] | ioctl_download | buttons[1] ),

	.dn_addr(ioctl_addr[16:0]),
	.dn_data(ioctl_dout),
	.dn_wr(ioctl_wr),

	.video_ce(ce_vid),
	.video_r(r),
	.video_g(g),
	.video_b(b),

	.video_hs(hs),
	.video_vs(vs),
	.video_vblank(vblank),
	.video_hblank(hblank),

	.audio_out(audio),

	.start2(m_start2|btn_start_2),
	.start1(m_start1|btn_start_1),
	.coin1(m_coin|btn_coin_1|btn_coin_2),

	.fire1(m_fire),
	.right1(m_right),
	.left1(m_left),
	.down1(m_down),
	.up1(m_up),

	.fire2(m_fire_2),
	.right2(m_right_2),
	.left2(m_left_2),
	.down2(m_down_2),
	.up2(m_up_2),
	
	.dip_sw1(m_dip_sw1),
	.dip_sw2(m_dip_sw2)

	
);

endmodule

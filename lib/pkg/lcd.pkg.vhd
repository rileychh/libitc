library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;

package itc_lcd is
	constant l_width : integer := 128;
	constant l_height : integer := 160;
	constant l_depth : integer := 24;
	constant l_px_cnt : integer := l_width * l_height;
	constant l_addr_width : integer := log(2, l_px_cnt);

	-- pixel type, can represent memory data or color
	subtype l_px_t is unsigned(l_depth - 1 downto 0);
	type l_px_arr_t is array (integer range <>) of l_px_t;

	-- address types, can represent location of pixel
	subtype l_addr_t is integer range 0 to l_px_cnt - 1; -- a 1D address (row * width + col)
	type l_coord_t is array (0 to 1) of integer range 0 to l_height - 1; -- a 2D address (row, col)

	-- packed pixel type: an address concatenated with a pixel (39 downto 24 => addr, 23 downto 0 => data)
	subtype l_pack_t is unsigned(log(2, l_px_cnt) + l_depth - 1 downto 0);

	--------------------------------------------------------------------------------
	-- color constants
	--------------------------------------------------------------------------------

	constant black   : l_px_t := x"000000";
	constant blue    : l_px_t := x"0000ff";
	constant red     : l_px_t := x"ff0000";
	constant magenta : l_px_t := x"ff00ff";
	constant green   : l_px_t := x"00ff00";
	constant cyan    : l_px_t := x"00ffff";
	constant yellow  : l_px_t := x"ffff00";
	constant white   : l_px_t := x"ffffff";

	--------------------------------------------------------------------------------
	-- command constants
	-- only the used commands are listed here
	--------------------------------------------------------------------------------

	constant l_slpout  : u8_t := x"11";
	constant l_frmctr1 : u8_t := x"b1";
	constant l_frmctr2 : u8_t := x"b2";
	constant l_frmctr3 : u8_t := x"b3";
	constant l_pwctr1  : u8_t := x"c0";
	constant l_pwctr2  : u8_t := x"c1";
	constant l_pwctr3  : u8_t := x"c2";
	constant l_pwctr4  : u8_t := x"c3";
	constant l_pwctr5  : u8_t := x"c4";
	constant l_vmctr1  : u8_t := x"c5";
	constant l_gmctrp1 : u8_t := x"e0"; -- aka gamctrp1
	constant l_gmctrn1 : u8_t := x"e1"; -- aka gamctrn1
	constant l_madctl  : u8_t := x"36";
	constant l_caset   : u8_t := x"2a";
	constant l_raset   : u8_t := x"2b";
	constant l_dispon  : u8_t := x"29";
	constant l_ramwr   : u8_t := x"2c";

	--------------------------------------------------------------------------------
	-- initialization commands and arguments
	--------------------------------------------------------------------------------

	constant l_init : u8_arr_t(0 to 79) := (
		l_frmctr1, x"05", x"3c", x"3c",
		l_frmctr2, x"05", x"3c", x"3c",
		l_frmctr3, x"05", x"3c", x"3c", x"05", x"3c", x"3c",
		l_pwctr1, x"28", x"08", x"04",
		l_pwctr2, x"c0",
		l_pwctr3, x"0d", x"00",
		l_pwctr4, x"8d", x"2a",
		l_pwctr5, x"8d", x"ee",
		l_vmctr1, x"1a",
		l_gmctrp1, x"04", x"22", x"07", x"0a", x"2e", x"30", x"25", x"2a", x"28", x"26", x"2e", x"3a", x"00", x"01", x"03", x"13",
		l_gmctrn1, x"04", x"16", x"06", x"0d", x"2d", x"26", x"23", x"27", x"27", x"25", x"2d", x"3b", x"00", x"01", x"04", x"13",
		l_madctl, x"c0",
		l_caset, x"00", x"02", x"00", x"81",
		l_raset, x"00", x"01", x"00", x"a0",
		l_dispon,
		l_ramwr
	);
	constant l_init_dc : std_logic_vector(0 to 79) := "01110111011111101110101101101101011111111111111110111111111111111101011110111100";
end package;

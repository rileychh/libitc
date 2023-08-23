library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;

entity lcd_mix_test is
	port (
		clk                                                     : in std_logic;
		rst_n                                                   : in std_logic;
		lcd_sclk, lcd_mosi, lcd_ss_n, lcd_dc, lcd_bl, lcd_rst_n : out std_logic;
		sw                                                      : in u8r_t
	);
end lcd_mix_test;

architecture arch of lcd_mix_test is
	signal x : integer range -127 to 127;
	signal y : integer range -159 to 159;
	signal font_start : std_logic;
	signal font_busy : std_logic;
	signal text_size : integer range 1 to 12;
	signal text_data : string(1 to 12);
	signal text_count : integer range 1 to 12;
	signal addr : l_addr_t;
	signal text_color : l_px_t;
	signal bg_color : l_px_t;
	-- signal text_color_array : l_px_arr_t;
	signal clear : std_logic;
	signal con : std_logic;
	signal pic_data : std_logic_vector(23 downto 0);
	signal pic_addr : l_addr_t;
begin

	bongo_inst : entity work.bongo(syn)
		port map(
			address => std_logic_vector(to_unsigned(pic_addr, 15)),
			clock   => clk,
			q       => pic_data
		);
	-- sBzGFdyQjS_inst : entity work.sBzGFdyQjS(syn)
	-- 	port map(
	-- 		address => std_logic_vector(to_unsigned(pic_addr, 8)),
	-- 		clock   => clk,
	-- 		q       => pic_data
	-- 	);
	lcd_test_inst : entity work.lcd_mix(arch)
		port map(
			clk        => clk,
			rst_n      => rst_n,
			x          => 0,
			y          => 10,
			font_start => sw(0),
			font_busy  => font_busy,
			text_size  => to_integer(sw(3 to 7)),
			text_data  => "text_data   ",
			-- text_count       => text_count,
			-- addr             => addr,
			text_color       => green,
			bg_color         => white,
			text_color_array => (blue, blue, blue, blue, blue, blue, blue, blue, blue, blue, blue, blue),
			clear            => sw(1),
			lcd_sclk         => lcd_sclk,
			lcd_mosi         => lcd_mosi,
			lcd_ss_n         => lcd_ss_n,
			lcd_dc           => lcd_dc,
			lcd_bl           => lcd_bl,
			lcd_rst_n        => lcd_rst_n,
			con              => sw(2),

			pic_addr => pic_addr,
			pic_data => pic_data
		);
end arch;

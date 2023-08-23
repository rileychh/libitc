library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.itc.all;
use work.itc_lcd.all;

entity test is
	port (
		clk, rst_n                                              : in std_logic;
		lcd_sclk, lcd_mosi, lcd_ss_n, lcd_dc, lcd_bl, lcd_rst_n : out std_logic;
		sw                                                      : in u8r_t
	);
end entity;
architecture arch of test is
	signal x, y : integer;
	signal font_start, font_busy, clear, draw_start, draw_done : std_logic;
begin
	edge_inst_lcd_done : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => font_busy,
			rising  => draw_start,
			falling => draw_done
		);
	gen_font_inst : entity work.gen_font(arch)
		port map(
			clk              => clk,
			rst_n            => rst_n,
			x                => 0,
			y                => 10,
			font_start       => sw(0),
			font_busy        => open,
			text_size        => 1,
			data             => "1234567890  ",
			addr             => open,
			text_color       => green,
			bg_color         => white,
			text_color_array => (green, green, green, green, green, green, green, green, green, green, green, green),
			clear            => sw(7),
			lcd_sclk         => lcd_sclk,
			lcd_mosi         => lcd_mosi,
			lcd_ss_n         => lcd_ss_n,
			lcd_dc           => lcd_dc,
			lcd_bl           => lcd_bl,
			lcd_rst_n        => lcd_rst_n
		);
	-- process (clk, rst_n)
	-- begin
	-- 	if rst_n = '0' then
	-- 		x <= 0;
	-- 		y <= 10;
	-- 		clear <= '1';
	-- 		font_start <= '0';
	-- 	end if;
	-- end process;
end arch;

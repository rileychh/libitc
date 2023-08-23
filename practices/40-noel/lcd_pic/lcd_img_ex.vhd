library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;

entity lcd_img_ex is
	port (
		-- --sys
		clk, rst_n : in std_logic;
		-- lcd
		lcd_sclk, lcd_mosi, lcd_ss_n, lcd_dc, lcd_bl, lcd_rst_n : out std_logic;
		sw                                                      : in u8r_t
	);
end lcd_img_ex;

architecture arch of lcd_img_ex is

	signal wr_ena : std_logic;
	signal l_addr : l_addr_t;
	signal l_data_i : std_logic_vector(23 downto 0);
	signal l_data : l_px_t;
	signal lcd_sclk_1, lcd_mosi_1, lcd_ss_n_1, lcd_dc_1, lcd_bl_1, lcd_rst_n_1 : std_logic;
	signal lcd_sclk_2, lcd_mosi_2, lcd_ss_n_2, lcd_dc_2, lcd_bl_2, lcd_rst_n_2 : std_logic;

begin
	-- gen_font_inst : entity work.gen_font(arch)
	-- 	port map(
	-- 		clk              => clk,
	-- 		rst_n            => rst_n,
	-- 		x                => 0,
	-- 		y                => 10,
	-- 		font_start       => sw(0),
	-- 		font_busy        => open,
	-- 		text_size        => 1,
	-- 		data             => "1234567890  ",
	-- 		addr             => open,
	-- 		text_color       => green,
	-- 		bg_color         => white,
	-- 		text_color_array => (green, green, green, green, green, green, green, green, green, green, green, green),
	-- 		clear            => sw(7),
	-- 		lcd_sclk         => lcd_sclk_1,
	-- 		lcd_mosi         => lcd_mosi_1,
	-- 		lcd_ss_n         => lcd_ss_n_1,
	-- 		lcd_dc           => lcd_dc_1,
	-- 		lcd_bl           => lcd_bl_1,
	-- 		lcd_rst_n        => lcd_rst_n_1
	-- 	);

	lcd_inst : entity work.lcd(arch)
		port map(
			clk        => clk,
			rst_n      => rst_n,
			lcd_sclk   => lcd_sclk_2,
			lcd_mosi   => lcd_mosi_2,
			lcd_ss_n   => lcd_ss_n_2,
			lcd_dc     => lcd_dc_2,
			lcd_bl     => lcd_bl_2,
			lcd_rst_n  => lcd_rst_n_2,
			brightness => 100,
			wr_ena     => wr_ena,
			addr       => l_addr,
			data       => l_data
		);

	bongo_inst : entity work.bongo(syn)
		port map(
			address => std_logic_vector(to_unsigned(l_addr, 15)),
			clock   => clk,
			q       => l_data_i
		);
	l_data <= unsigned(l_data_i);
	process (clk, rst_n) begin

		if rst_n = '0' then
			wr_ena <= '0';
			l_addr <= 0;
		elsif rising_edge(clk) then
			if l_addr < l_px_cnt - 1 then
				if wr_ena = '0' then
					wr_ena <= '1';
				else
					wr_ena <= '0';
					l_addr <= l_addr + 1;
				end if;
			else
				wr_ena <= '0';
			end if;
		end if;
	end process;
end arch;

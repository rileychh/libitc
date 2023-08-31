library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;

entity test is
	port (
		clk                                                     : in std_logic;
		rst_n                                                   : in std_logic;
		lcd_sclk, lcd_mosi, lcd_ss_n, lcd_dc, lcd_bl, lcd_rst_n : out std_logic
	);
end test;

architecture arch of test is
	signal wr_ena : std_logic;
	signal l_addr, pic_addr : l_addr_t;
	signal l_data : l_px_t;
	signal p_data_i : std_logic_vector(23 downto 0);
	signal p_data : l_px_t;

	signal x : integer range -127 to 127;
	signal y : integer range -159 to 159;
	signal font_start, font_busy, l_clear : std_logic;
	signal pic_data_o : l_px_t;
begin
	bongo_inst : entity work.bongo(syn)
		port map(
			address => std_logic_vector(to_unsigned(pic_addr, 8)),
			clock   => clk,
			q       => p_data_i
		);
	-- lcd_inst : entity work.lcd(arch)
	-- 	port map(
	-- 		clk        => clk,
	-- 		rst_n      => rst_n,
	-- 		lcd_sclk   => lcd_sclk,
	-- 		lcd_mosi   => lcd_mosi,
	-- 		lcd_ss_n   => lcd_ss_n,
	-- 		lcd_dc     => lcd_dc,
	-- 		lcd_bl     => lcd_bl,
	-- 		lcd_rst_n  => lcd_rst_n,
	-- 		brightness => 100,
	-- 		wr_ena     => wr_ena,
	-- 		addr       => l_addr,
	-- 		data       => pic_data_o
	-- 	);
	lcd_mix_inst : entity work.lcd_mix(arch)
		port map(
			clk              => clk,
			rst_n            => rst_n,
			x                => x,
			y                => y,
			font_start       => font_start,
			font_busy        => font_busy,
			text_size        => 1,
			text_data        => "text_data   ",
			text_count       => open,
			addr             => open,
			text_color       => green,
			bg_color         => white,
			text_color_array => (green, green, green, green, green, green, green, green, green, green, green, green),
			clear            => l_clear,
			lcd_sclk         => lcd_sclk,
			lcd_mosi         => lcd_mosi,
			lcd_ss_n         => lcd_ss_n,
			lcd_dc           => lcd_dc,
			lcd_bl           => lcd_bl,
			lcd_rst_n        => lcd_rst_n,
			con              => '1',
			pic_addr         => l_addr,
			pic_data         => pic_data_o
		);

	p_data <= unsigned(p_data_i);
	process (clk, rst_n)
	begin
		if rst_n = '0' then
		elsif rising_edge(clk) then
			pic_data_o <= to_data(l_paste(l_addr, white, p_data, (0, 0), 16, 16));
			pic_addr <= to_addr(l_paste(l_addr, white, p_data, (0, 0), 16, 16));
			-- if l_addr < l_px_cnt - 1 then
			-- 	if wr_ena = '0' then
			-- 		wr_ena <= '1';
			-- 	else
			-- 		wr_ena <= '0';
			-- 		l_addr <= l_addr + 1;
			-- 	end if;
			-- else
			-- 	wr_ena <= '0';
			-- end if;
		end if;
	end process;
end arch;

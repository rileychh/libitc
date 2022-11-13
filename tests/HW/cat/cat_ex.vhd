library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
--
use work.itc.all;
use work.itc_lcd.all;

entity cat_ex is
	port (
		-- --sys
		clk, rst_n : in std_logic;
		-- lcd
		lcd_sclk, lcd_mosi, lcd_ss_n, lcd_dc, lcd_bl, lcd_rst_n : out std_logic
	);
end cat_ex;

architecture arch of cat_ex is

	signal wr_ena : std_logic;
	signal l_addr : l_addr_t;
	signal l_data_i : std_logic_vector(23 downto 0);
	signal l_data : l_px_t;
	--lcd_draw
	signal bg_color, text_color : l_px_t;
	signal addr : l_addr_t;
	signal text_size : integer range 1 to 12;
	signal data : string(1 to 12);
	signal font_start, font_busy, lcd_clear : std_logic;
	signal draw_done, draw_start : std_logic;
	signal x : integer range -5 to 159;
	signal y : integer range 0 to 159;
begin

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
	-- 		data       => l_data
	-- 	);
	lcd_draw : entity work.gen_font(arch)
		port map(
			clk        => clk,
			rst_n      => rst_n,
			x          => x,
			y          => y,
			font_start => font_start,
			font_busy  => font_busy,
			text_size  => text_size,
			data       => data,
			text_color => text_color,
			addr       => addr,
			bg_color   => bg_color,
			clear      => lcd_clear,
			lcd_sclk   => lcd_sclk,
			lcd_mosi   => lcd_mosi,
			lcd_ss_n   => lcd_ss_n,
			lcd_dc     => lcd_dc,
			lcd_bl     => lcd_bl,
			lcd_rst_n  => lcd_rst_n

		);
	cat_inst : entity work.cat(syn)
		port map(
			address => std_logic_vector(to_unsigned(l_addr, 15)),
			clock   => clk,
			q       => l_data_i
		);
	bg_color <= unsigned(l_data_i);

	process (clk, rst_n) begin
		if rst_n = '0' then
			font_start <= '1';
			lcd_clear <= '0';
			text_size <= 1;
			x <= 0;
			y <= 0;
			text_color <= green;
			data <= " 1234567890 ";
		elsif rising_edge(clk) then

		end if;
	end process;
end arch;

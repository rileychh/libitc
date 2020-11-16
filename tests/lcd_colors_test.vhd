library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;

entity lcd_colors_test is
	port (
		-- sys
		clk, rst_n : in std_logic;
		-- lcd
		lcd_sclk, lcd_mosi, lcd_ss_n, lcd_dc, lcd_bl, lcd_rst_n : out std_logic;
		-- seg
		seg_led, seg_com : out u8r_t;
		-- debug
		dbg_a, dbg_b : out u8r_t
	);
end lcd_colors_test;

architecture arch of lcd_colors_test is

	signal wr_ena : std_logic;
	signal pixel_addr : integer range 0 to lcd_pixel_cnt - 1;
	signal pixel_data : u16_t;

	constant colors_std : u16_arr_t(0 to 7) := (
		x"0000", x"f800", x"07e0", x"ffe0", x"001f", x"f81f", x"07ff", x"ffff"
	);

	-- https://github.com/morhetz/gruvbox
	constant colors_gruvbox : u16_arr_t(0 to 7) := (
		x"c7de", x"1e64", x"1cd2", x"26b3", x"8a30", x"858c", x"6b53", x"63ed"
	);

	signal clk_color : std_logic;
	signal color_sel : integer range 0 to 7;

begin

	lcd_inst : entity work.lcd(arch)
		port map(
			clk        => clk,
			rst_n      => rst_n,
			lcd_sclk   => lcd_sclk,
			lcd_mosi   => lcd_mosi,
			lcd_ss_n   => lcd_ss_n,
			lcd_dc     => lcd_dc,
			lcd_bl     => lcd_bl,
			lcd_rst_n  => lcd_rst_n,
			brightness => x"ff",
			wr_ena     => wr_ena,
			pixel_addr => pixel_addr,
			pixel_data => pixel_data
		);

	clk_inst: entity work.clk(arch)
	generic map (
		freq => 1
	)
	port map (
		clk_in => clk,
		rst_n => rst_n,
		clk_out => clk_color
	);

	process (clk_color, rst_n) begin
		if rst_n = '0' then
			color_sel <= 0;
		elsif rising_edge(clk_color) then
			if color_sel = color_sel'high then
				color_sel <= 0;
			else
				color_sel <= color_sel + 1;
			end if;
		end if;
	end process;

	seg_inst: entity work.seg(arch)
	port map (
		clk => clk,
		rst_n => rst_n,
		seg_led => seg_led,
		seg_com => seg_com,
		data => "       " & to_string(color_sel, color_sel'high, 10, 1),
		dot => (others => '0')
	);

	process (clk, rst_n) begin
		if rst_n = '0' then
			wr_ena <= '0';
		elsif rising_edge(clk) then
			if pixel_addr = pixel_addr'high then
				pixel_addr <= 0;
			else
				pixel_addr <=  pixel_addr + 1;
			end if;

			pixel_data <= colors_std(color_sel);
			wr_ena <= '1';
		end if;
	end process;

end arch;

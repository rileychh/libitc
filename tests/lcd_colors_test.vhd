library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;

entity lcd_colors_test is
	port (
		-- sys
		clk, rst_n : in std_logic;
		-- sw
		sw : in u8r_t;
		-- lcd
		lcd_sclk, lcd_mosi, lcd_ss_n, lcd_dc, lcd_bl, lcd_rst_n : out std_logic;
		-- seg
		seg_led, seg_com : out u8r_t
	);
end lcd_colors_test;

architecture arch of lcd_colors_test is

	signal wr_ena : std_logic;
	signal pixel_addr : integer range 0 to l_px_cnt - 1;
	signal pixel_data : l_px_t;

	constant colors_std : l_px_arr_t(0 to 7) := (
		x"000000", x"0000ff", x"ff0000", x"ff00ff", x"00ff00", x"00ffff", x"ffff00", x"ffffff"
	);

	constant colors_gray : l_px_arr_t(0 to 7) := (
		x"111111", x"333333", x"555555", x"777777", x"999999", x"bbbbbb", x"dddddd", x"ffffff"
	);

	-- https://github.com/morhetz/gruvbox
	constant colors_gruvbox : l_px_arr_t(0 to 7) := (
		x"fbf1c7", x"cc241d", x"98971a", x"d79921", x"458588", x"b16286", x"689d6a", x"7c6f64"
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
			brightness => 100,
			wr_ena     => wr_ena,
			pixel_addr => pixel_addr,
			pixel_data => pixel_data
		);

	seg_inst: entity work.seg(arch)
	port map (
		clk => clk,
		rst_n => rst_n,
		seg_led => seg_led,
		seg_com => seg_com,
		data => "       " & to_string(color_sel, color_sel'high, 10, 1),
		dot => (others => '0')
	);

	process (clk, rst_n)
		variable timer : integer range 0 to sys_clk_freq / 1;	
	begin
		if rst_n = '0' then
			wr_ena <= '0';
			pixel_addr <= 0;
			color_sel <= 0;
		elsif rising_edge(clk) then
			if pixel_addr = pixel_addr'high then
				pixel_addr <= 0;
			else
				pixel_addr <= pixel_addr + 1;
			end if;

			if sw(0) = '1' then
				color_sel <= pixel_addr / 2560;
			else
				if timer = timer'high then
					timer := 0;
					color_sel <= color_sel + 1;
				else
					timer := timer + 1;
				end if;
			end if;

			case to_integer(reverse(sw(6 to 7))) is
				when 0 => pixel_data <= colors_std(color_sel);
				when 1 => pixel_data <= colors_gray(color_sel);
				when 2 => pixel_data <= colors_gruvbox(color_sel);
				when others => pixel_data <= (others => '0');
			end case;
			wr_ena <= '1';
		end if;
	end process;

end arch;

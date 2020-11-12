library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;

entity lcd_test is
	port (
		-- sys
		clk, rst_n : in std_logic;
		-- lcd
		lcd_sclk, lcd_mosi, lcd_ss_n, lcd_dc, lcd_bl, lcd_rst : out std_logic;
		-- debug
		dbg_a, dbg_b : out u8r_t
	);
end lcd_test;

architecture arch of lcd_test is

	function rainbow return pixels_t is
		variable color : pixel_t := x"f00";
		variable result : pixels_t;
	begin
		for row in 0 to lcd_height - 1 loop
			for col in 0 to lcd_width - 1 loop
				result(col + row * lcd_width) := color;
			end loop;
			color := color + 1;
		end loop;

		return result;
	end function;

begin

	dbg_a <= clk & rst_n & lcd_sclk & lcd_mosi & lcd_ss_n & lcd_dc & lcd_rst & '0';

	lcd_inst : entity work.lcd(arch)
		port map(
			clk        => clk,
			rst_n      => rst_n,
			lcd_sclk   => lcd_sclk,
			lcd_mosi   => lcd_mosi,
			lcd_ss_n   => lcd_ss_n,
			lcd_dc     => lcd_dc,
			lcd_bl     => lcd_bl,
			lcd_rst    => lcd_rst,
			brightness => x"ff",
			lcd_data => (others => x"0f0"),
			dbg        => dbg_b
		);

end arch;

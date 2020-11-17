library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;

entity lcd_image_test_bicolor is
	port (
		--sys
		clk, rst_n : in std_logic;
		-- lcd
		lcd_sclk, lcd_mosi, lcd_ss_n, lcd_dc, lcd_bl, lcd_rst_n : out std_logic
	);
end lcd_image_test_bicolor;

architecture arch of lcd_image_test_bicolor is

	signal wr_ena : std_logic;
	signal pixel_addr : integer range 0 to lcd_pixel_cnt - 1;
	signal pixel_data_i : std_logic_vector(0 downto 0);
	signal pixel_data : lcd_pixel_t;

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

	image_bicolor_inst : entity work.image_bicolor(syn)
		port map(
			address => std_logic_vector(to_unsigned(pixel_addr, 15)),
			clock   => clk,
			q       => pixel_data_i -- {{ i => inner }}
		);
	pixel_data <= x"000000" when pixel_data_i = "0" else x"ffffff";

	process (clk, rst_n) begin
		if rst_n = '0' then
			wr_ena <= '0';
			pixel_addr <= 0;
		elsif rising_edge(clk) then
			if wr_ena = '0' then
				if pixel_addr < lcd_pixel_cnt - 1 then
					pixel_addr <= pixel_addr + 1;
					wr_ena <= '1';
				else
					wr_ena <= '0';
				end if;
			else
				wr_ena <= '0';
			end if;
		end if;
	end process;

end arch;

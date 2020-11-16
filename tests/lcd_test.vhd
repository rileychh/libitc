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
		lcd_sclk, lcd_mosi, lcd_ss_n, lcd_dc, lcd_bl, lcd_rst_n : out std_logic;
		-- debug
		dbg_a, dbg_b : out u8r_t
	);
end lcd_test;

architecture arch of lcd_test is

	signal wr_ena : std_logic;
	signal pixel_addr : integer range 0 to lcd_pixel_cnt - 1;
	signal pixel_data : std_logic_vector(15 downto 0);

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
			pixel_data => unsigned(pixel_data)
		);

	image_inst : entity work.image(syn)
		port map(
			address => std_logic_vector(to_unsigned(pixel_addr, 15)),
			clock   => clk,
			q       => pixel_data
		);

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

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
--
use work.itc.all;
use work.itc_lcd.all;

entity lcd_image_test is
	port (
		-- --sys
		clk, rst_n : in std_logic;
		-- lcd
		lcd_sclk, lcd_mosi, lcd_ss_n, lcd_dc, lcd_bl, lcd_rst_n : out std_logic
	);
end lcd_image_test;

architecture arch of lcd_image_test is

	signal wr_ena : std_logic;
	signal l_addr : l_addr_t;
	signal l_data_i : std_logic_vector(23 downto 0);
	signal l_data : l_px_t;

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
			addr       => l_addr,
			data       => l_data
		);

	image_inst : entity work.image(syn)
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

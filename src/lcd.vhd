library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;

entity lcd is
	port (
		-- system
		clk, rst_n : in std_logic;
		-- lcd
		lcd_sclk, lcd_mosi, lcd_ss_n, lcd_bl, lcd_rst : out std_logic;
		-- user logic
		brightness : in byte_t;
		lcd_data   : in pixels_t
	);
end lcd;

architecture arch of lcd is

	signal spi_ena, spi_busy : std_logic;
	signal spi_in : byte_t;
	signal spi_done : std_logic;

	type state_t is (init, run);
	signal state : state_t;

begin

	spi_inst : entity work.spi(arch)
		generic map(
			cpol     => 0,
			cpha     => 0,
			bus_freq => 1_000_000
		)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			mosi    => lcd_mosi,
			sclk    => lcd_sclk,
			ss_n    => lcd_ss_n,
			ena     => spi_ena,
			busy    => spi_busy,
			data_in => spi_in
		);

	edge_inst : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => spi_busy,
			rising  => open,
			falling => spi_done
		);

	process (clk, rst_n)
		variable byte_cnt : integer range 0 to lcd_bit_cnt / 8 - 1;
	begin
		if rst_n = '0' then
			spi_ena <= '0';
			byte_cnt := 0;
		elsif rising_edge(clk) then
			case state is
				when init =>

				when run =>
					spi_ena <= '0';
					if spi_done = '1' then
						spi_in <= to_bytes(lcd_data)(byte_cnt);
						spi_ena <= '1';
					end if;

					if byte_cnt = byte_cnt'high then
						byte_cnt := 0;
					else
						byte_cnt := byte_cnt + 1;
					end if;
			end case;
		end if;
	end process;

end arch;

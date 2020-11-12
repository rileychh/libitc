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
		lcd_sclk, lcd_mosi, lcd_ss_n, lcd_dc, lcd_bl, lcd_rst : out std_logic;
		-- user logic
		brightness : in u8_t;
		lcd_data   : in pixels_t;
		-- debug
		dbg : out u8r_t
	);
end lcd;

architecture arch of lcd is

	signal clk_spi : std_logic;
	signal spi_ena, spi_busy, spi_done : std_logic;
	signal spi_data : u8_t;

	type spi_state_t is (idle, send);
	signal spi_state : spi_state_t;
	type lcd_state_t is (rst_wait, wake, wake_wait, init, draw);
	signal lcd_state : lcd_state_t;

begin

	lcd_rst <= rst_n;
	dbg <= spi_busy & spi_ena & reverse(to_unsigned(lcd_state_t'pos(lcd_state), 6));

	--------------------------------------------------------------------------------
	-- SPI interface
	--------------------------------------------------------------------------------

	clk_inst : entity work.clk(arch)
		generic map(
			freq => 12_500_000 * 2
		)
		port map(
			clk_in  => clk,
			rst_n   => rst_n,
			clk_out => clk_spi
		);

	process (clk_spi, rst_n)
		variable bit_cnt : integer range 7 downto 0;
	begin
		if rst_n = '0' then
			lcd_sclk <= '0';
			lcd_ss_n <= '1';
			spi_busy <= '1';
			spi_state <= idle;
			bit_cnt := 7;
		elsif rising_edge(clk_spi) then
			case spi_state is
				when idle =>
					lcd_sclk <= '0';

					if spi_ena = '1' then
						lcd_mosi <= spi_data(bit_cnt);
						lcd_ss_n <= '0';
						spi_busy <= '1';
						spi_state <= send;
					else
						lcd_ss_n <= '1';
						spi_busy <= '0';
					end if;

				when send =>
					if lcd_sclk = '1' then -- sclk falling edge
						lcd_sclk <= '0';
						lcd_mosi <= spi_data(bit_cnt);
					else -- sclk rising edge
						lcd_sclk <= '1';

						if bit_cnt = 0 then
							bit_cnt := 7;
							spi_busy <= '0';
							spi_state <= idle;
						else
							bit_cnt := bit_cnt - 1;
						end if;
					end if;
			end case;
		end if;
	end process;

	edge_inst : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => spi_busy,
			rising  => open,
			falling => spi_done
		);

	--------------------------------------------------------------------------------
	-- main process
	--------------------------------------------------------------------------------

	process (clk, rst_n)
		variable timer : integer range 0 to 120 * (sys_clk_freq / 1000) - 1; -- this timer can count up to 120ms
		variable byte_cnt : integer range 0 to lcd_bit_cnt / 8 - 1;
	begin
		if rst_n = '0' then
			spi_ena <= '0';
			lcd_state <= wake;
			timer := 0;
			byte_cnt := 0;
		elsif rising_edge(clk) then
			case lcd_state is
				when rst_wait => -- wait for 120ms
					if timer = timer'high then
						timer := 0;
						lcd_state <= wake;
					else
						timer := timer + 1;
					end if;

				when wake => -- sen SLPOUT command
					lcd_dc <= '0';
					spi_data <= lcd_slpout;
					spi_ena <= '1';

					if spi_done = '1' then
						spi_ena <= '0';
						lcd_state <= wake_wait;
					end if;

				when wake_wait => -- wait for 120ms
					if timer = timer'high then
						lcd_dc <= lcd_init_dc(byte_cnt);
						spi_data <= lcd_init(byte_cnt);
						spi_ena <= '1';
						lcd_state <= init;
					else
						timer := timer + 1;
					end if;

				when init =>
					if spi_done = '1' then
						if byte_cnt = lcd_init'high then
							byte_cnt := 0;
							lcd_dc <= '1';
							spi_data <= to_bytes(lcd_data)(byte_cnt);
							lcd_state <= draw;
						else
							byte_cnt := byte_cnt + 1;
							lcd_dc <= lcd_init_dc(byte_cnt);
							spi_data <= lcd_init(byte_cnt);
						end if;
					end if;

				when draw =>
					if spi_done = '1' then
						if byte_cnt = byte_cnt'high then
							byte_cnt := 0;
						else
							byte_cnt := byte_cnt + 1;
						end if;

						spi_data <= to_bytes(lcd_data)(byte_cnt);
					end if;
			end case;
		end if;
	end process;

	--------------------------------------------------------------------------------
	-- backlight control
	--------------------------------------------------------------------------------

	pwm_inst : entity work.pwm(arch)
		generic map(
			pwm_freq => sys_clk_freq / i8_t'high + 1
		)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			duty    => brightness,
			pwm_out => lcd_bl
		);

end arch;

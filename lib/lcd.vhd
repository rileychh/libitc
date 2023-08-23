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
		lcd_sclk, lcd_mosi, lcd_ss_n, lcd_dc, lcd_bl, lcd_rst_n : out std_logic;
		-- user logic
		brightness : in integer range 0 to 100;
		wr_ena     : in std_logic;
		addr       : in l_addr_t;
		data       : in l_px_t
	);
end lcd;

architecture arch of lcd is

	signal clk_spi : std_logic;
	signal spi_ena, spi_busy, spi_done : std_logic;
	signal spi_width : integer range 0 to l_px_t'length;
	signal spi_data : l_px_t;
	signal buffer_addr : integer range 0 to l_px_cnt - 1;
	signal buffer_data_i : std_logic_vector(l_px_t'range);
	signal buffer_data : l_px_t;

	type spi_state_t is (idle, send);
	signal spi_state : spi_state_t;
	type lcd_state_t is (rst_wait, wake, wake_wait, init, draw);
	signal lcd_state : lcd_state_t;

begin

	lcd_rst_n <= rst_n;

	framebuffer_inst : entity work.framebuffer(syn)
		port map(
			clock     => clk,
			wren      => wr_ena,
			wraddress => std_logic_vector(to_unsigned(addr, 15)),
			data      => std_logic_vector(data),
			rdaddress => std_logic_vector(to_unsigned(buffer_addr, 15)),
			q         => buffer_data_i
		);
	buffer_data <= unsigned(buffer_data_i);

	--------------------------------------------------------------------------------
	-- SPI interface
	--------------------------------------------------------------------------------

	clk_inst : entity work.clk(arch)
		generic map(
			freq => 4_000_000 * 2
		)
		port map(
			clk_in  => clk,
			rst_n   => rst_n,
			clk_out => clk_spi
		);

	process (clk_spi, rst_n)
		variable bit_cnt : integer range l_px_t'length - 1 downto 0;
	begin
		if rst_n = '0' then
			lcd_sclk <= '0';
			lcd_ss_n <= '1';
			spi_busy <= '1';
			spi_state <= idle;
			bit_cnt := bit_cnt'high;
		elsif rising_edge(clk_spi) then
			case spi_state is
				when idle =>
					lcd_sclk <= '0';

					if spi_ena = '1' then
						bit_cnt := spi_width - 1;
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
	begin
		if rst_n = '0' then
			spi_ena <= '0';
			lcd_state <= rst_wait;
			buffer_addr <= 0;
			timer := 0;
		elsif rising_edge(clk) then
			case lcd_state is
				when rst_wait => -- wait for reset (120ms)
					if timer = timer'high then
						timer := 0;
						lcd_state <= wake;
					else
						timer := timer + 1;
					end if;

				when wake => -- send SLPOUT command
					lcd_dc <= '0';
					spi_width <= 8;
					spi_data(7 downto 0) <= l_slpout;
					spi_ena <= '1';

					if spi_done = '1' then
						spi_ena <= '0';
						lcd_state <= wake_wait;
					end if;

				when wake_wait => -- wait for 120ms
					if timer = timer'high then
						lcd_state <= init;
					else
						timer := timer + 1;
					end if;

				when init =>
					lcd_dc <= l_init_dc(buffer_addr);
					spi_data(7 downto 0) <= l_init(buffer_addr);
					spi_ena <= '1';

					if spi_done = '1' then
						if buffer_addr = l_init'high then
							buffer_addr <= 0;
							lcd_state <= draw;
						else
							buffer_addr <= buffer_addr + 1;
						end if;
					end if;

				when draw =>
					lcd_dc <= '1';
					spi_width <= 24;
					spi_data <= buffer_data;

					if spi_done = '1' then
						if buffer_addr = buffer_addr'high then
							buffer_addr <= 0;
						else
							buffer_addr <= buffer_addr + 1;
						end if;
					end if;
			end case;
		end if;
	end process;

	--------------------------------------------------------------------------------
	-- backlight control
	--------------------------------------------------------------------------------

	pwm_inst : entity work.pwm(arch)
		generic map(
			pwm_freq => 10_000
		)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			duty    => brightness,
			pwm_out => lcd_bl
		);

end arch;

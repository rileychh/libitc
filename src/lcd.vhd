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
		brightness : in u8_t;
		wr_ena     : in std_logic;
		pixel_addr : in integer range 0 to lcd_pixel_cnt - 1;
		pixel_data : in u16_t;
		-- debug
		dbg : out u8r_t
	);
end lcd;

architecture arch of lcd is

	signal clk_spi : std_logic;
	signal spi_ena, spi_busy, spi_done : std_logic;
	signal spi_data : u8_t;
	signal buffer_addr : integer range 0 to lcd_frame_width / 8 - 1;
	signal buffer_data_i : std_logic_vector(7 downto 0);
	signal buffer_data : u8_t;

	type spi_state_t is (idle, send);
	signal spi_state : spi_state_t;
	type lcd_state_t is (wake, wake_wait, init, draw);
	signal lcd_state : lcd_state_t;

begin

	lcd_rst_n <= rst_n;
	buffer_data <= unsigned(buffer_data_i);
	dbg <= spi_busy & spi_ena & reverse(to_unsigned(lcd_state_t'pos(lcd_state), 6));

	framebuffer_inst : entity work.framebuffer(syn)
		port map(
			clk         => clk,
			wr_ena      => wr_ena,
			pixel_addr  => std_logic_vector(to_unsigned(pixel_addr, 15)),
			pixel_in    => std_logic_vector(pixel_data),
			buffer_addr => std_logic_vector(to_unsigned(buffer_addr, 16)),
			buffer_out  => buffer_data_i
		);

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
	begin
		if rst_n = '0' then
			spi_ena <= '0';
			lcd_state <= wake;
			buffer_addr <= 0;
			timer := 0;
		elsif rising_edge(clk) then
			case lcd_state is
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
						lcd_state <= init;
					else
						timer := timer + 1;
					end if;

				when init =>
					lcd_dc <= lcd_init_dc(buffer_addr);
					spi_data <= lcd_init(buffer_addr);
					spi_ena <= '1';

					if spi_done = '1' then
						if buffer_addr = lcd_init'high then
							buffer_addr <= 0;
							lcd_state <= draw;
						else
							buffer_addr <= buffer_addr + 1;
						end if;
					end if;

				when draw =>
					lcd_dc <= '1';
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
			pwm_freq => sys_clk_freq / i8_t'high + 1
		)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			duty    => brightness,
			pwm_out => lcd_bl
		);

end arch;

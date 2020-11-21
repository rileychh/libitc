--!pp on
--!inc const_pkg.vhd

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;
use work.itc108_2_const.all;

entity itc108_2 is
	port (
		-- sys
		clk, rst_n : in std_logic;
		-- sw
		sw : in u8r_t;
		-- key
		key_row : in u4r_t;
		key_col : out u4r_t;
		-- lcd
		lcd_sclk, lcd_mosi, lcd_ss_n, lcd_dc, lcd_bl, lcd_rst_n : out std_logic;
		-- seg
		seg_led, seg_com : out u8r_t;
		-- mot
		mot_ch  : out u2r_t;
		mot_ena : out std_logic;
		-- fake rs232 => uart
		uart_rx : in std_logic; -- receive pin
		uart_tx : out std_logic -- transmit pin
	);
end itc108_2;

architecture arch of itc108_2 is

	type mode_t is (idle, tft, dht, tsl, full);
	signal mode : mode_t;

	type state_t is (idle, execute);
	signal state : state_t;

	signal rst_i : std_logic;
	signal speed_level : integer range 1 to 3;
	signal prev_temp : integer range 0 to 99;

	signal timer_ena : std_logic;
	signal timer_load, msec : i32_t;
	signal pressed, key_on_press : std_logic;
	signal key : i4_t;
	signal brightness : integer range 0 to 100;
	signal lcd_wr_ena : std_logic;
	signal pixel_addr : integer range 0 to l_px_cnt - 1;
	signal pixel_data : l_px_t;
	signal seg_data : string(1 to 8) := (others => ' ');
	signal seg_dot : u8r_t;
	signal temp : integer range 0 to 99;
	signal dir : std_logic;
	signal speed : i8_t;

	signal tx_ena, tx_busy, rx_busy, rx_err : std_logic;
	signal tx_data, rx_data : u8_t;
	signal rx_done : std_logic;

	signal buf : u8_arr_t(0 to 63);
	signal buf_cnt : integer range buf'range;

	signal bg_addr, icon_addr : integer range 0 to l_px_cnt - 1;
	signal bg_data_i, icon_data_i : std_logic_vector(0 downto 0);
	signal bg_data, icon_data : std_logic;

begin
	-- include init bootstrap port map
	--!inc inst.vhd

	process (clk, rst_n) begin
		if rst_n = '0' then
			mode <= idle;
			timer_ena <= '0';
			timer_load <= 0;
			seg_data <= (others => ' ');
			seg_dot <= (others => '0');

			tx_ena <= '0';
			buf_cnt <= 0;
		elsif rising_edge(clk) then
			if key_on_press = '1' then
				case key is
					when key_start =>
						timer_ena <= '1';
						rst_i <= '0';
						case to_integer(sw) is
							when 0 =>
								mode <= tft;
							when 1 =>
								mode <= dht;
							when 2 =>
								mode <= tsl;
							when 3 =>
								mode <= full;
							when others =>
								timer_ena <= '0';
								mode <= idle;
						end case;
					when key_stop =>
						timer_load <= msec;
						timer_ena <= '0';
						mode <= idle;
					when key_rst =>
						timer_load <= 0;
						timer_ena <= '0';
						rst_i <= '1';
					when others => null;
				end case;
			end if;

			case mode is
				when idle =>
					if rst_i = '1' then -- start reset
						brightness <= 0;
					end if;
					speed <= 0;

				when tft =>
					case msec / 1000 is
						when 0 =>
							timer_ena <= '1';
							if pixel_addr < pixel_addr'high then
								lcd_wr_ena <= '1';
								pixel_data <= white;
								pixel_addr <= pixel_addr + 1;
							end if;
							brightness <= 100;
						when 1 to 4 => -- col0-49 blue, 50-99 green, 100-159 red, bl 20%
							timer_ena <= '1';
							if pixel_addr < pixel_addr'high then
								lcd_wr_ena <= '1';
								case pixel_addr / 128 is
									when 0 to 49 =>
										pixel_data <= blue;
									when 50 to 99 =>
										pixel_data <= green;
									when others =>
										pixel_data <= red;
								end case;
								pixel_addr <= pixel_addr + 1;
							end if;
							--!def second (msec / 1000)
							brightness <= 20 + 20 * (second - 1);
						when 5 to 9 =>
							brightness <= 100 - 20 * (second - 5);
						when 10 =>
							pixel_addr <= 0;
							timer_load <= 0;
							timer_ena <= '0'; -- loop back to 0
						when others => null;
					end case;

					if msec mod 1000 = 1 then -- on every second (can't be .0sec)
						pixel_addr <= 0; -- reset pixel address for next frame
					end if;

				when dht =>
					--!def incrs if speed_level /= 3 then speed_level <= speed_level + 1; end if
					--!def decrs if speed_level /= 1 then speed_level <= speed_level - 1; end if
					if key_on_press = '1' then
						case key is
							when key_up =>
								incrs;
							when key_down =>
								decrs;
							when others => null;
						end case;
					end if;

					if msec mod 1000 = 1 then -- on every second
						if temp > prev_temp then
							incrs;
						elsif temp < prev_temp then
							decrs;
						end if;
						prev_temp <= temp;
					end if;

					speed <= 50 + speed_level * 60;
					seg_data <= to_string(speed_level, speed_level'high, 10, 2) & "SP" &
						to_string(temp, temp'high, 10, 2) & seg_deg & 'C';
					seg_dot <= "00110000";

				when tsl =>
				when full =>
			end case;
		end if;
	end process;

end arch;

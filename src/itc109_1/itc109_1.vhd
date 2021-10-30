--!pp on
--!inc const_pkg.vhd

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;
use work.itc109_1_const.all;

entity itc109_1 is
	port (
		-- sys
		clk, rst_n : in std_logic;
		-- sw
		sw : in u8r_t;
		-- key
		key_row : in u4r_t;
		key_col : out u4r_t;
		-- dht
		dht_data : inout std_logic;
		-- tsl
		tsl_scl, tsl_sda : inout std_logic;
		-- lcd
		lcd_sclk, lcd_mosi, lcd_ss_n, lcd_dc, lcd_bl, lcd_rst_n : out std_logic;
		-- seg
		seg_led, seg_com : out u8r_t;
		-- mot
		mot_ch  : out u2r_t;
		mot_ena : out std_logic;
		-- tts
		tts_scl, tts_sda : inout std_logic;
		tts_mo           : in unsigned(2 downto 0);
		tts_rst_n        : out std_logic;
		-- led
		led_r, led_g, led_y : out std_logic;
		-- debug
		dbg_a, dbg_b : out u8r_t
	);
end itc109_1;

architecture arch of itc109_1 is

	signal clk_main : std_logic;

	signal timer_ena : std_logic;
	signal timer_load, msec : i32_t;

	signal pressed, key_on_press : std_logic;
	signal key : i4_t;

	signal l_wr_ena : std_logic;
	signal l_addr : l_addr_t;
	signal l_data : l_px_t := white;

	signal seg_data : string(1 to 8) := (others => ' ');
	signal seg_dot : u8r_t;

	signal temp_int, temp_int_i, hum_int, hum_int_i : integer range 0 to 99;
	signal temp_dec, temp_dec_i, hum_dec, hum_dec_i : integer range 0 to 9;

	signal lux, lux_i : i16_t;

	signal dir : std_logic;
	signal speed : integer range 0 to 100;

	signal tts_ena, tts_busy : std_logic;
	signal tts_data : u8_arr_t(0 to 63);
	signal tts_len : integer range 1 to 64;

	type mode_t is (lcd, tts, sensor, full);
	signal mode : mode_t;

	type state_t is (rst, init, start);
	signal state : state_t;

	type digit_addr_t is array (0 to 9) of integer range 0 to 20479;
	signal digit_addr : digit_addr_t;
	type digit_data_i_t is array (0 to 9) of std_logic_vector(0 downto 0);
	signal digit_data_i : digit_data_i_t;
	type digit_data_t is array (0 to 9) of std_logic;
	signal digit_data : digit_data_t;
	signal sensor_bg_data_i : std_logic_vector(2 downto 0);
	signal sensor_bg_data : l_px_t;

	signal lux_str : string(1 to 5);
	signal temp_str, hum_str : string(1 to 4);
	signal tts_fn : integer range 1 to 3;
	signal tts_vol : integer range 2 to 4 := 3;
	signal tts_mute : std_logic := '0';
	signal tts_args : string(1 to 5) := "UOL03";
	signal tts_cmd : u8_arr_t(0 to 3);

begin

	--!inc inst.vhd

	-- dbg_a <= tts_scl & tts_sda & reverse(tts_mo) & tts_rst_n & tts_ena & tts_busy;
	-- dbg_b <= (others => '0');

	-- led_r <= tts_mo(0);
	-- led_g <= tts_mo(1);
	-- led_y <= tts_mo(2);

	process (clk, rst_n)
		variable running : std_logic;
	begin
		if rst_n = '0' then
			mode <= lcd;
			state <= rst;
			running := '0';
			timer_ena <= '0';
			timer_load <= 0;
			l_wr_ena <= '1';
			l_addr <= 0;
			l_data <= white;
			seg_data <= (others => ' ');
			seg_dot <= (others => '0');
			speed <= 0;
			tts_ena <= '0';
			tts_data <= (others => (others => '0'));
			tts_len <= 1;

			tts_fn <= 1;
			tts_vol <= 3;
			tts_mute <= '0';
			tts_args <= "UOL03";
		elsif rising_edge(clk_main) then
			if l_addr < l_addr'high then
				l_addr <= l_addr + 1;
			else
				l_addr <= 0;
			end if;

			if key_on_press = '1' then
				case key is
					when key_start =>
						running := not running;
						state <= init;
						case to_integer(sw(0 to 1)) is
							when 0 =>
								mode <= lcd;
							when 1 =>
								mode <= tts;
							when 2 =>
								mode <= sensor;
							when 3 =>
								mode <= full;
							when others => null;
						end case;
					when key_rst =>
						state <= rst;
					when others => null;
				end case;
			end if;

			case mode is
				when lcd =>
					case state is
						when rst =>
							-- seg_data <= "00000001";
							timer_load <= 0;
							timer_ena <= '0';
							l_wr_ena <= '1';
							l_data <= white;

						when init =>
							-- seg_data <= "00000002";
							timer_ena <= '1';
							l_wr_ena <= '1';
							l_data <= white;

							if msec > 10 then
								timer_load <= 0;
								timer_ena <= '0';
								state <= start;
							end if;

						when start =>
							if running = '1' then
								timer_ena <= '1';
							else
								timer_load <= msec;
								timer_ena <= '0';
							end if;

							case msec / 500 is
								when 0 | 2 =>
									timer_ena <= '1';
									case to_coord(l_addr)(0) is
										when 0 to 79 =>
											l_data <= white;
										when others =>
											l_data <= black;
									end case;
								when 1 | 3 =>
									case to_coord(l_addr)(0) is
										when 0 to 79 =>
											l_data <= black;
										when others =>
											l_data <= white;
									end case;
								when 4 to 9 => -- 9 to 4
									digit_addr <= (others => l_addr);
									l_data <= repeat(digit_data(9 - (msec / 500) + 4), 24);
								when 10 => -- 3
									digit_addr <= (others => l_addr);
									l_data <= l_map(repeat(digit_data(3), 24), black, green);
								when 11 => -- 2
									digit_addr <= (others => l_addr);
									l_data <= l_map(repeat(digit_data(2), 24), black, red);
								when 12 => -- 1
									digit_addr <= (others => l_addr);
									l_data <= l_map(repeat(digit_data(1), 24), black, blue);
								when 13 => -- loop
									timer_load <= 0;
									timer_ena <= '0'; -- loop back to 0
								when others => null;
							end case;
					end case;

				when tts =>
					case state is
						when rst =>
							timer_load <= 0;
							timer_ena <= '0';

						when init =>
							timer_ena <= '1';

							case msec / 500 is
								when 0 | 2 =>
									seg_data <= (others => '8');
									seg_dot <= (others => '1');
								when 1 | 3 =>
									seg_data <= (others => ' ');
									seg_dot <= (others => '0');
								when others =>
									seg_data <= "F1.UOL03";
									seg_dot <= (others => '0');
									tts_fn <= 1;
									tts_vol <= 3;
									tts_mute <= '0';
									tts_args <= "UOL03";
									tts_cmd <= (tts_set_vol, x"d2", tts_set_channel, x"07");
									timer_load <= 0;
									timer_ena <= '0';
									state <= start;
							end case;

						when start =>
							tts_ena <= not tts_mute;
							tts_data(0 to 4 + tts_t_test'high) <= tts_cmd & tts_t_test;
							tts_len <= 4 + tts_t_test'length;
							seg_data <= "F" & to_string(tts_fn, tts_fn'high, 10, 1) & "." & tts_args;

							if key_on_press = '1' then
								case key is
									when key_up =>
										case tts_fn is
											when 1 =>
												if tts_vol < tts_vol'high then
													tts_vol <= tts_vol + 1;
												end if;
											when 2 =>
											when 3 =>
											when others =>
										end case;

									when key_down =>
										case tts_fn is
											when 1 =>
												if tts_vol > tts_vol'low then
													tts_vol <= tts_vol - 1;
												end if;
											when 2 =>
											when 3 =>
											when others =>
										end case;

									when key_ok =>
										case tts_vol is
											when 2 =>
												tts_cmd(1) <= x"be";
											when 3 =>
												tts_cmd(1) <= x"d2";
											when 4 =>
												tts_cmd(1) <= x"e6";
										end case;
										-- case tts_channel is
										-- when 0 =>
										-- when others =>
										-- end case;

									when key_fn =>
										if tts_fn < tts_fn'high then
											tts_fn <= tts_fn + 1;
										else
											tts_fn <= 1;
										end if;
									when others => null;
								end case;
							end if;

					end case;

				when sensor =>
					if key_on_press = '1' then
						case key is
							when others => null;
						end case;
					end if;

					case state is
						when rst =>
						when init =>
							state <= start;
						when start =>
							l_wr_ena <= running;

							if sw(2) = '1' then
								hum_int_i <= hum_int;
								hum_dec_i <= hum_dec;
							end if;
							if sw(3) = '1' then
								temp_int_i <= temp_int;
								temp_dec_i <= temp_dec;
							end if;
							if sw(4) = '1' then
								lux_i <= lux;
							end if;

							if sw(6) = '1' then
								temp_str <= to_string(temp_int_i, temp_int'high, 10, 2) & "." & to_string(temp_dec_i, temp_dec'high, 10, 1);
							else
								temp_str <= "OFF ";
							end if;
							if sw(5) = '1' then
								hum_str <= to_string(hum_int_i, hum_int'high, 10, 2) & "." & to_string(hum_dec_i, hum_dec'high, 10, 1);
							else
								hum_str <= "OFF ";
							end if;
							if sw(7) = '1' then
								lux_str <= to_string(lux_i, lux'high, 10, 3) & ".0";
							else
								lux_str <= "OFF  ";
							end if;

							-- seg_data <= "Hello123";

							--!def lp_hum_i l_paste_txt(l_addr, lp_temp_i, hum_str, (140, 20))
							--!def lp_temp_i l_paste_txt(l_addr, lp_lux_i, temp_str, (100, 20))
							--!def lp_lux_i l_paste_txt(l_addr, sensor_bg_data, lux_str, (40, 20))
							l_data <= lp_hum_i;
					end case;

				when full =>
					if key_on_press = '1' then
						case key is
							when others => null;
						end case;
					end if;

					case state is
						when rst =>
						when init =>
						when start =>
					end case;
			end case;
		end if;
	end process;

end arch;

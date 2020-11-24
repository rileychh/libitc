--!pp on
--!inc const_pkg.vhd

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;
use work.itc108_1_const.all;

entity itc108_1 is
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
end itc108_1;

architecture arch of itc108_1 is

	type mode_t is (tft, dht, tsl, full);
	signal mode : mode_t;

	type state_t is (rst, stop, start);
	signal state : state_t;

	signal clk_main : std_logic;
	signal speed_level : integer range 1 to 3;
	signal prev_temp : integer range 0 to 99;
	signal icon_color : l_px_t;
	signal icon_dir : integer range 0 to 3;
	signal prev_lux : i16_t;
	signal tsl_mode : character := 'R';

	signal timer_ena : std_logic;
	signal timer_load, msec : i32_t;

	signal pressed, key_on_press : std_logic;
	signal key : i4_t;

	signal brightness : integer range 0 to 100;
	signal l_wr_ena : std_logic;
	signal l_addr : l_addr_t;
	signal l_data : l_px_t;
	signal icon_addr : integer range 0 to l_px_cnt - 1;
	signal icon_data_i : std_logic_vector(0 downto 0);
	signal icon_data : l_px_t;

	signal seg_data : string(1 to 8) := (others => ' ');
	signal seg_dot : u8r_t;

	signal temp : integer range 0 to 99;

	signal lux : i16_t;

	signal dir : std_logic;
	signal speed : integer range 0 to 100;

	signal tts_ena, tts_busy : std_logic;
	signal tts_data : u8_arr_t(0 to tts_rpt_len - 1);
	signal tts_len : integer range 1 to tts_rpt_len;

begin

	--!inc inst.vhd

	icon_data <= white when icon_data_i(0) = '1' else black;

	dbg_a <= tts_scl & tts_sda & reverse(tts_mo) & tts_rst_n & tts_ena & tts_busy;
	dbg_b <= (others => '0');

	led_r <= tts_mo(0);
	led_g <= tts_mo(1);
	led_y <= tts_mo(2);

	process (clk_main, rst_n) begin
		if rst_n = '0' then
			mode <= tft;
			state <= rst;
			timer_ena <= '0';
			timer_load <= 0;
			brightness <= 0;
			seg_data <= (others => ' ');
			seg_dot <= (others => '0');
			speed <= 0;
			tts_ena <= '0';
		elsif rising_edge(clk_main) then
			if l_addr < l_addr'high then
				l_addr <= l_addr + 1;
			else
				l_addr <= 0;
			end if;

			if key_on_press = '1' and key = key_start then
				case to_integer(sw) is
					when 0 =>
						mode <= tft;
					when 1 =>
						mode <= dht;
					when 2 =>
						mode <= tsl;
					when 3 =>
						mode <= full;
					when others => null;
				end case;
			end if;

			case mode is
				when tft =>
					if key_on_press = '1' then
						case key is
							when key_rst => state <= rst;
							when key_stop => state <= stop;
							when key_start => state <= start;
							when others => null;
						end case;
					end if;

					case state is
						when rst =>
							timer_load <= 0;
							timer_ena <= '0';
							brightness <= 0;

						when stop =>
							timer_load <= msec;
							timer_ena <= '0';
							l_wr_ena <= '0';

						when start =>
							timer_ena <= '1';
							l_wr_ena <= '1';
							--!def second (msec / 1000)
							case second is
								when 0 =>
									timer_ena <= '1';
									brightness <= 100;
								when 1 to 4 => -- row 0-49 blue, 50-99 green, 100-159 red, bl 20%
									brightness <= 20 * second;
								when 5 to 9 =>
									brightness <= 100 - 20 * (second - 5);
								when 10 =>
									timer_load <= 0;
									timer_ena <= '0'; -- loop back to 0
								when others => null;
							end case;

							case second is
								when 0 =>
									l_data <= white;
								when others =>
									case to_coord(l_addr)(0) is
										when 0 to 49 =>
											l_data <= blue;
										when 50 to 99 =>
											l_data <= green;
										when others =>
											l_data <= red;
									end case;
							end case;
					end case;

				when dht =>
					--!def incrs if speed_level /= 3 then speed_level <= speed_level + 1; end if
					--!def decrs if speed_level /= 1 then speed_level <= speed_level - 1; end if
					if key_on_press = '1' then
						case key is
							when key_rst => state <= rst;
							when key_stop => state <= stop;
							when key_start => state <= start;
							when key_up => incrs;
							when key_down => decrs;
							when others => null;
						end case;
					end if;

					case state is
						when rst =>
							seg_data <= (others => ' ');
							seg_dot <= (others => '0');
							state <= stop;

						when stop =>
							timer_ena <= '0';
							speed <= 0;

						when start =>
							timer_ena <= '1';
							speed <= 25 + speed_level * 25;
							seg_data <= to_string(speed_level, speed_level'high, 10, 2) & "SP" &
								to_string(temp, temp'high, 10, 2) & seg_deg & 'C';
							seg_dot <= "00110000";

							if msec mod 1000 = 1 then
								if temp > prev_temp then
									incrs;
								elsif temp < prev_temp then
									decrs;
								end if;
								prev_temp <= temp;
							end if;
					end case;

				when tsl =>
					if key_on_press = '1' then
						case key is
							when key_rst => state <= rst;
							when key_stop => state <= stop;
							when key_start => state <= start;
							when key_ok => state <= start;
							when others => null;
						end case;
					end if;

					case state is
						when rst =>
							timer_load <= 0;
							timer_ena <= '0';
							brightness <= 0;
							speed <= 0;

						when stop =>
							tsl_mode <= 'S';
							if key_on_press = '1' then
								case key is
									when key_up =>
										dir <= '0';
										icon_color <= blue;
										icon_dir <= 1;
									when key_down =>
										dir <= '1';
										icon_color <= black;
										icon_dir <= 0;
									when others => null;
								end case;
							end if;

						when start =>
							timer_ena <= '1';
							l_wr_ena <= '1';
							brightness <= 100;
							speed <= 50;
							tsl_mode <= 'R';

							if msec mod 2000 = 1 then
								if lux > 15 then
									dir <= '1';
									icon_color <= black;
									icon_dir <= 0;
								else
									dir <= '0';
									icon_color <= blue;
									icon_dir <= 1;
								end if;
								prev_lux <= lux;
							end if;
					end case;

					--!def lp_lux l_paste_txt(l_addr, lp_mode, lux_str(1) & ' ' & lux_str(2) & ' ' & lux_str(3) & ' ' & lux_str(4), (76, 45))
					--!def lux_str to_string(prev_lux, 9999, 10, 4)
					--!def lp_mode l_paste_txt(l_addr, lp_rt, "M o d e :  " & tsl_mode, (20, 20))
					--!def lp_rt l_paste_txt(l_addr, to_data(lp_icon), "R T :", (120, 16))
					--!def lp_icon l_paste(l_addr, white, l_map(icon_data, black, icon_color), (108, 76), 32, 32)
					l_data <= lp_lux;
					icon_addr <= l_mirror(to_addr(lp_icon), icon_dir, 32, 32);

				when full =>
					if key_on_press = '1' then
						case key is
							when key_rst => state <= rst;
							when key_stop => state <= stop;
							when key_start => state <= start;
							when others => null;
						end case;
					end if;

					case state is
						when rst =>
							timer_load <= 0;
							timer_ena <= '0';
							brightness <= 0;
							speed <= 0;
							seg_data <= (others => ' ');
							seg_dot <= (others => '0');
							state <= stop;

						when stop =>
							timer_load <= 0;
							timer_ena <= '0';
							l_wr_ena <= '0';
							tts_ena <= '0';
							speed <= 0;

						when start =>
							timer_ena <= '1';

							if msec = 0 then
								prev_lux <= lux;
								prev_temp <= temp;
								speed_level <= 2;
								l_wr_ena <= '1';
								brightness <= 100;
								tsl_mode <= 'R';
								tts_ena <= '1';
							elsif tts_busy = '0' then
								tts_data(0 to 56) <=
								txt_rpt_1 & to_string(lux, lux'high, 10, 4) &
								txt_rpt_2 & to_string(temp, temp'high, 10, 2) &
								txt_rpt_3 & to_string(speed_level, speed_level'high, 10, 1);

								if lux > 15 then
									dir <= '1';
									icon_color <= black;
									icon_dir <= 0;
									tts_data(57 to 66) <= txt_rpt_4_ccw;
								else
									dir <= '0';
									icon_color <= blue;
									icon_dir <= 1;
									tts_data(57 to 66) <= txt_rpt_4_cw;
								end if;
								prev_lux <= lux;

								if temp > prev_temp then
									incrs;
									tts_data(67 to 76) <= txt_rpt_5_up;
								elsif temp < prev_temp then
									decrs;
									tts_data(67 to 76) <= txt_rpt_5_down;
								else
									tts_data(67 to 76) <= txt_rpt_5_same;
								end if;
								prev_temp <= temp;
							end if;

							speed <= 25 + speed_level * 25;

							seg_data <= to_string(speed_level, speed_level'high, 10, 2) & "SP" &
								to_string(prev_temp, prev_temp'high, 10, 2) & seg_deg & 'C';
							seg_dot <= "00110000";

							l_data <= lp_lux;
							icon_addr <= l_mirror(to_addr(lp_icon), icon_dir, 32, 32);
					end case;
			end case;
		end if;
	end process;

end arch;

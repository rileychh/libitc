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
		mot_ena : out std_logic
	);
end itc108_1;

architecture arch of itc108_1 is

	type mode_t is (tft, dht, tsl, full);
	signal mode : mode_t;

	type state_t is (idle, execute);
	signal state : state_t;

	signal clk_main : std_logic;
	signal speed_level : integer range 1 to 3;
	signal prev_temp : integer range 0 to 99;
	signal icon_color : l_px_t;
	signal icon_dir : integer range 0 to 3;
	signal small_txt_addr : integer range 0 to 34;
	signal txt_addr : integer range 0 to 5 * 7 * 7 - 1;
	signal txt_data : l_px_t;
	signal tsl_mode : character := 'R';

	signal timer_ena : std_logic;
	signal timer_load, msec : i32_t;
	signal pressed, key_on_press : std_logic;
	signal key : i4_t;
	signal brightness : integer range 0 to 100;
	signal l_wr_ena : std_logic;
	signal l_addr : l_addr_t;
	signal l_data : l_px_t;
	signal seg_data : string(1 to 8) := (others => ' ');
	signal seg_dot : u8r_t;
	signal temp : integer range 0 to 99;
	signal dir : std_logic;
	signal speed : integer range 0 to 100;
	signal bg_addr, icon_addr : integer range 0 to l_px_cnt - 1;
	signal bg_data_i, icon_data_i : std_logic_vector(0 downto 0);
	signal bg_data, icon_data : l_px_t;
	signal lux : i16_t;

begin

	--!inc inst.vhd

	bg_data <= white when bg_data_i(0) = '1' else black;
	icon_data <= white when icon_data_i(0) = '1' else black;

	process (clk_main, rst_n) begin
		if rst_n = '0' then
			mode <= tft;
			timer_ena <= '0';
			timer_load <= 0;
			brightness <= 0;
			seg_data <= (others => ' ');
			seg_dot <= (others => '0');
			speed <= 0;
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
					case key is
						when key_start =>
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

						when key_stop =>
							timer_load <= msec;
							timer_ena <= '0';
							l_wr_ena <= '0';

						when key_rst =>
							timer_load <= 0;
							timer_ena <= '0';
							brightness <= 0;

						when others => null;
					end case;

				when dht =>
					--!def incrs if speed_level /= 3 then speed_level <= speed_level + 1; end if
					--!def decrs if speed_level /= 1 then speed_level <= speed_level - 1; end if
					case key is
						when key_start =>
							timer_ena <= '1';
							speed <= 25 + speed_level * 25;
							seg_data <= to_string(speed_level, speed_level'high, 10, 2) & "SP" &
								to_string(temp, temp'high, 10, 2) & seg_deg & 'C';
							seg_dot <= "00110000";

							if msec mod 1000 = 1 then -- on every second
								if temp > prev_temp then
									incrs;
								elsif temp < prev_temp then
									decrs;
								end if;
								prev_temp <= temp;
							end if;

						when key_stop =>
							speed <= 0;

						when key_rst =>
							speed <= 0;
							seg_data <= (others => ' ');
							seg_dot <= (others => '0');

						when key_up =>
							incrs;

						when key_down =>
							decrs;

						when others => null;
					end case;

				when tsl =>
					case key is
						when key_start =>
							timer_ena <= '1';
							l_wr_ena <= '1';
							brightness <= 100;
							speed <= 50;
							tsl_mode <= 'R';

						when key_stop =>
							timer_load <= 0;
							timer_ena <= '0';
							tsl_mode <= 'S';

						when key_rst =>
							timer_load <= 0;
							timer_ena <= '0';
							brightness <= 0;
							speed <= 0;

						when key_ok =>
							timer_ena <= '1';
							l_wr_ena <= '1';
							brightness <= 100;
							speed <= 50;
							tsl_mode <= 'R';

						when others => null;
					end case;

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
					end if;

					bg_addr <= l_addr;
					--!def lp_mode l_paste_txt(l_addr, to_data(lp_icon), "M o d e :  " & tsl_mode, (20, 20))
					--!def lp_icon l_paste(l_addr, bg_data, l_map(icon_data, black, icon_color), (108, 76), 32, 32)
					l_data <= lp_mode;
					icon_addr <= l_mirror(to_addr(lp_icon), icon_dir, 32, 32);
				when full =>
			end case;
		end if;
	end process;

end arch;

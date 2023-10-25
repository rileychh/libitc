library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;

entity itc112_2 is
	port (
		-- system
		clk   : in std_logic;
		rst_n : in std_logic;
		-- key
		key_row : in u4r_t;
		key_col : out u4r_t;
		-- sw
		sw : in u8r_t;
		-- 8x8 dot
		dot_red, dot_green, dot_com : out u8r_t;
		-- lcd
		lcd_sclk, lcd_mosi, lcd_ss_n, lcd_dc, lcd_bl, lcd_rst_n : out std_logic;
		-- seg
		seg_led, seg_com : out u8r_t;
		-- led
		led_g, led_r, led_y : out std_logic;
		-- rgb
		rgb : out std_logic_vector(0 to 2);
		--buzzer
		buz : out std_logic;
		-- mot
		mot_ch  : out u2r_t;
		mot_ena : out std_logic;
		-- uart
		uart_rx : in std_logic; -- receive pin
		uart_tx : out std_logic -- transmit pin
		-- dbg_b   : out u8r_t
	);
end itc112_2;

architecture arch of itc112_2 is
	-- system
	type mode_t is (res, idle, produce, store, bonus);
	signal mode : mode_t;
	type produce_mode_t is (sun, water, fan, all_done);
	signal produce_mode : produce_mode_t;
	type uart_t is (idle, password, check, success, err);
	signal uart_mod : uart_t;
	type store_or_take_out is (store, take_out);
	signal energy_mod : store_or_take_out; -- choose store or take out
	type bonus_mode_t is (move, stop);
	signal bonus_mode : bonus_mode_t;

	signal store_value : integer range 0 to 9999; -- store take mod value
	signal pass_str : string(1 to 4); -- pass string
	signal count : integer range 0 to 50; -- count(pass, value)
	signal pass : u8_arr_t(0 to 3); -- password
	signal inter_rst : std_logic; --keypad reset
	signal can_use_energy, store_energy, produce_energy : integer; -- energy
	signal buz_flag : std_logic; -- buz
	signal bonus1_flag, bonus2_flag, bonus3_flag : std_logic; -- bonus dot flag	
	signal value, sun_value, water_value, fan_value : integer range 0 to 9; --machine amount
	signal sun_flag, water_flag, fan_flag, back_flag : std_logic; -- setup flag
	signal value_1, value_10, value_100, value_1000 : integer range 0 to 9;
	signal input_value : integer range 0 to 9999; -- input_value <= value_1000 * 1000 + value_100 * 100 + value_10 * 10 + value_1;
	-- key
	signal pressed, key_pressed : std_logic;
	signal key_data : i4_t;
	signal key_pad : integer range 0 to 9;
	-- dot
	signal data_r, data_g : u8r_arr_t(0 to 7);
	signal dot_x, dot_y : integer range 0 to 7;
	constant all_clear : u8r_arr_t(0 to 7) := (x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00");
	-- lcd
	signal x : integer range -127 to 127;
	signal y : integer range -159 to 159;
	signal font_start, font_busy, draw_done : std_logic;
	signal text_data : string(1 to 12);
	signal text_color : l_px_arr_t(1 to 12);
	signal lcd_clear : std_logic;
	signal bg_color : l_px_t;
	signal lcd_con : std_logic;
	signal pic_addr : l_addr_t;
	signal pic_data : l_px_t;
	signal lcd_count : integer range 0 to 5;
	-- seg
	signal seg_data : string(1 to 8);
	signal seg_dot : u8r_t;
	-- rgb
	signal rgb_color : l_px_t;
	-- mot
	signal mot_dir : std_logic;
	signal mot_speed : integer range 0 to 100;
	-- uart
	signal tx_data, rx_data : u8_t := x"00";
	signal rx_start, rx_done : std_logic;
	signal tx_ena, tx_busy, rx_busy, rx_err : std_logic;
	-- timer
	signal timer_ena : std_logic;
	signal load, msec : i32_t;
	-- lcd text color
	constant all_green : l_px_arr_t(1 to 12) := (green, green, green, green, green, green, green, green, green, green, green, green);
begin
	key_inst : entity work.key(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			key_row => key_row,
			key_col => key_col,
			pressed => pressed,
			key     => key_data
		);
	dot_inst : entity work.dot(arch)
		generic map(
			common_anode => '0'
		)
		port map(
			clk       => clk,
			rst_n     => rst_n,
			dot_red   => dot_red,
			dot_green => dot_green,
			dot_com   => dot_com,
			data_r    => data_g,
			data_g    => data_r
		);
	lcd_mix_inst : entity work.lcd_mix(arch)
		port map(
			clk              => clk,
			rst_n            => rst_n,
			x                => x,
			y                => y,
			font_start       => font_start,
			font_busy        => font_busy,
			text_size        => 1,
			text_data        => text_data,
			text_count       => open,
			addr             => open,
			text_color       => green,
			bg_color         => bg_color,
			text_color_array => text_color,
			clear            => lcd_clear,
			con              => lcd_con,
			pic_addr         => pic_addr,
			pic_data         => pic_data,
			lcd_sclk         => lcd_sclk,
			lcd_mosi         => lcd_mosi,
			lcd_ss_n         => lcd_ss_n,
			lcd_dc           => lcd_dc,
			lcd_bl           => lcd_bl,
			lcd_rst_n        => lcd_rst_n
		);
	seg_inst : entity work.seg(arch)
		generic map(
			common_anode => '1'
		)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			seg_led => seg_led,
			seg_com => seg_com,
			data    => seg_data,
			dot     => seg_dot
		);
	mot_inst : entity work.mot(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			mot_ch  => mot_ch,
			mot_ena => mot_ena,
			dir     => mot_dir,
			speed   => mot_speed
		);
	uart_inst : entity work.uart(arch)
		generic map(
			baud => 9600
		)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			uart_rx => uart_rx,
			uart_tx => uart_tx,
			tx_ena  => tx_ena,
			tx_busy => tx_busy,
			tx_data => tx_data,
			rx_busy => rx_busy,
			rx_err  => rx_err,
			rx_data => rx_data
		);
	edge_key_pressed_inst : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => pressed,
			rising  => key_pressed,
			falling => open
		);
	edge_lcd_done_inst : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => font_busy,
			rising  => open,
			falling => draw_done
		);
	edge_uart_rx_inst : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => rx_busy,
			rising  => rx_start,
			falling => rx_done
		);
	timer_inst : entity work.timer(arch)
		port map(
			clk   => clk,
			rst_n => rst_n,
			ena   => timer_ena,
			load  => load,
			msec  => msec
		);
	inter_rst <= '0' when (key_data = 7) and (key_pressed = '1') else '1';
	key_pad <= --key number to integer
		1 when (key_pressed = '1') and (key_data = 8) else
		2 when (key_pressed = '1') and (key_data = 9) else
		3 when (key_pressed = '1') and (key_data = 10) else
		4 when (key_pressed = '1') and (key_data = 4) else
		5 when (key_pressed = '1') and (key_data = 5) else
		6 when (key_pressed = '1') and (key_data = 6) else
		7 when (key_pressed = '1') and (key_data = 0) else
		8 when (key_pressed = '1') and (key_data = 1) else
		9 when (key_pressed = '1') and (key_data = 2) else
		0 when (key_pressed = '1') and (key_data = 3);
	process (clk, rst_n)
	begin
		if rst_n = '0' or inter_rst = '0' then
			produce_energy <= 0;
			lcd_count <= 0;
			buz_flag <= '0';
			buz <= '0';
			store_energy <= 1000;
			can_use_energy <= 0;
			led_g <= '0';
			led_r <= '0';
			led_y <= '0';
			mode <= res;
		elsif rising_edge(clk) then
			case mode is
				when res =>
					data_g <= all_clear;
					data_r <= all_clear;
					mot_dir <= '0';
					mot_speed <= 0;
					lcd_con <= '0';
					lcd_clear <= '1';
					bg_color <= white;
					if y < y'high then
						if font_busy = '0' then
							font_start <= '1';
						end if;
						if draw_done = '1' then
							font_start <= '0';
							y <= y + 1;
						end if;
					else
						if y >= y'high then
							lcd_clear <= '1';
							text_color <= all_green;
						end if;
					end if;
					seg_data <= "        ";
					timer_ena <= '1';
					load <= 0;
					if msec <= 500 then
						rgb <= "100";
					elsif msec <= 1000 then
						rgb <= "000";
					elsif msec <= 1500 then
						rgb <= "010";
					elsif msec <= 2000 then
						rgb <= "000";
					elsif msec <= 2500 then
						rgb <= "001";
					elsif msec <= 3000 then
						rgb <= "000";
					else
						mode <= idle;
					end if;
				when idle =>
					mot_speed <= 0;
					led_g <= '0';
					led_r <= '0';
					led_y <= '0';
					data_g <= all_clear;
					data_r <= all_clear;
					timer_ena <= '0';
					if key_pressed = '1' and key_data = 14 then
						seg_data <= to_string(can_use_energy, 9999, 10, 4) & "    ";
						if sw(0 to 2) = "100" then
							back_flag <= '0';
							sun_flag <= '0';
							water_flag <= '0';
							fan_flag <= '0';
							lcd_count <= 0;
							value <= 0;
							buz_flag <= '1';
							produce_mode <= sun;
							mode <= produce;
						elsif sw(0 to 2) = "010" then
							uart_mod <= idle;
							mode <= store;
							pass_str <= "    ";
							back_flag <= '0';
							value_1 <= 0;
							value_10 <= 0;
							value_100 <= 0;
							value_1000 <= 0;
							input_value <= 0;
						elsif sw(0 to 2) = "001" then
							bonus_mode <= move;
							dot_y <= 6;
							dot_x <= 1;
							bonus1_flag <= '0';
							bonus2_flag <= '0';
							bonus3_flag <= '0';
							mode <= bonus;
						end if;
					else
						if sw(0 to 2) = "100" then
							seg_data <= to_string(can_use_energy, 9999, 10, 4) & " GEN";
						elsif sw(0 to 2) = "010" then
							seg_data <= to_string(can_use_energy, 9999, 10, 4) & " STL";
						elsif sw(0 to 2) = "001" then
							seg_data <= to_string(can_use_energy, 9999, 10, 4) & " BON";
						else
							seg_data <= to_string(can_use_energy, 9999, 10, 4) & "    ";
						end if;
						lcd_clear <= '1';
					end if;
				when produce =>
					if buz_flag = '1' then
						if msec <= 1000 then
							timer_ena <= '1';
							buz <= '1';
						else
							buz_flag <= '0';
							timer_ena <= '0';
							buz <= '0';
						end if;
					else
						seg_data <= to_string(can_use_energy, 9999, 10, 4) & to_string(produce_energy, 9999, 10, 4);
						case produce_mode is
							when sun =>
								sun_value <= key_pad;
								if key_pressed = '1' and key_data = 14 then
									produce_energy <= sun_value * 250;
									sun_flag <= '1';
									produce_mode <= water;
								end if;
							when water =>
								water_value <= key_pad;
								if key_pressed = '1' and key_data = 14 then
									produce_energy <= produce_energy + water_value * 500;
									water_flag <= '1';
									produce_mode <= fan;
								end if;
							when fan =>
								fan_value <= key_pad;
								if key_pressed = '1' and key_data = 14 then
									produce_energy <= produce_energy + fan_value * 100;
									fan_flag <= '1';
									produce_mode <= all_done;
								end if;
							when all_done =>
								if key_pressed = '1' and key_data = 14 then
									if back_flag = '0' then
										produce_energy <= 0;
										can_use_energy <= can_use_energy + sun_value * 250 + water_value * 500 + fan_value * 100;
										seg_data <= to_string(can_use_energy, 9999, 10, 4) & to_string(produce_energy, 9999, 10, 4);
										back_flag <= '1';
									elsif back_flag = '1' then
										mode <= idle;
									end if;
								end if;
						end case;
					end if;
					case lcd_count is
						when 0 => -- white
							x <= 5;
							lcd_con <= '0';
							lcd_clear <= '1';
							bg_color <= white;
							if y < y'high then
								if font_busy = '0' then
									font_start <= '1';
								end if;
								if draw_done = '1' then
									font_start <= '0';
									y <= y + 1;
								end if;
							else
								if y >= y'high then
									y <= 10;
									lcd_clear <= '1';
									text_color <= all_green;
									lcd_count <= 1;
								end if;
							end if;
						when 1 =>
							bg_color <= white;
							lcd_clear <= '0';
							if y = 10 then
								if sun_flag = '1' then
									text_data <= to_string(sun_value, sun_value'high, 10, 1) & "           ";
								else
									text_data <= "            ";
								end if;
								font_start <= '1';
							end if;
							if draw_done = '1' then
								y <= 30;
								font_start <= '0';
								lcd_count <= 2;
							end if;
						when 2 =>
							if y = 30 then
								if water_flag = '1' then
									text_data <= to_string(water_value, water_value'high, 10, 1) & "           ";
								else
									text_data <= "            ";
								end if;
								font_start <= '1';
							end if;
							if draw_done = '1' then
								y <= 50;
								font_start <= '0';
								lcd_count <= 3;
							end if;
						when 3 =>
							if y = 50 then
								if fan_flag = '1' then
									text_data <= to_string(fan_value, fan_value'high, 10, 1) & "           ";
								else
									text_data <= "            ";
								end if;
								font_start <= '1';
							end if;
							if draw_done = '1' then
								y <= 10;
								font_start <= '0';
								lcd_count <= 1;
							end if;
						when 4 =>
						when 5 =>
					end case;
				when store =>
					case uart_mod is
						when idle =>
							seg_data <= to_string(can_use_energy, 9999, 10, 4) & "    ";
							lcd_clear <= '1';
							led_r <= '0';
							led_g <= '0';
							led_y <= '0';
							rgb <= "000";
							if key_pressed = '1' and key_data = 14 then
								if sw(0 to 1) = "10" then
									energy_mod <= store;
									uart_mod <= password;
									count <= 8;
								elsif sw(0 to 1) = "11" then
									energy_mod <= take_out;
									uart_mod <= password;
								end if;
							end if;
						when password =>
							seg_data <= to_string(can_use_energy, 9999, 10, 4) & to_string(store_energy, 9999, 10, 4);
							if rx_done = '1' then
								if to_integer(rx_data) = 13 then
									tx_ena <= '0';
									count <= 0;
									uart_mod <= check;
								else
									tx_ena <= '0';
									pass(count) <= rx_data;
									count <= count + 1;
								end if;
							end if;
							pass_str <= to_string(to_integer(pass(0)) - 48, 9, 10, 1) & to_string(to_integer(pass(1)) - 48, 9, 10, 1) & to_string(to_integer(pass(2)) - 48, 9, 10, 1) & to_string(to_integer(pass(3)) - 48, 9, 10, 1);
						when check =>
							if pass_str = "1234" then
								count <= 0;
								store_value <= 0;
								uart_mod <= success;
							else
								uart_mod <= err;
							end if;
						when success =>
							mot_speed <= 50;
							seg_data <= to_string(can_use_energy, 9999, 10, 4) & to_string(store_energy, 9999, 10, 4);
							case energy_mod is
								when store =>
									if key_pressed = '1' and key_data /= 7 and key_data /= 11 and key_data /= 12 and key_data /= 13 and key_data /= 14 and key_data /= 15 then
										value_1 <= key_pad;
										value_10 <= value_1;
										value_100 <= value_10;
										value_1000 <= value_100;
									end if;
									input_value <= value_1000 * 1000 + value_100 * 100 + value_10 * 10 + value_1;
									if key_pressed = '1' and key_data = 14 then
										if back_flag = '0' then
											if can_use_energy < input_value then
												can_use_energy <= 0;
												store_energy <= store_energy + can_use_energy;
											else
												can_use_energy <= can_use_energy - input_value;
												store_energy <= store_energy + input_value;
											end if;
											back_flag <= '1';
										else
											mode <= idle;
										end if;
									end if;
								when take_out =>
									if key_pressed = '1' and key_data /= 7 and key_data /= 11 and key_data /= 12 and key_data /= 13 and key_data /= 14 and key_data /= 15 then
										value_1 <= key_pad;
										value_10 <= value_1;
										value_100 <= value_10;
										value_1000 <= value_100;
									end if;
									input_value <= value_1000 * 1000 + value_100 * 100 + value_10 * 10 + value_1;
									if key_pressed = '1' and key_data = 14 then
										if back_flag = '0' then
											if store_energy < input_value then
												store_energy <= 0;
												can_use_energy <= can_use_energy + store_energy;
											else
												store_energy <= store_energy - input_value;
												can_use_energy <= can_use_energy + input_value;
											end if;
											back_flag <= '1';
										else
											mode <= idle;
										end if;
									end if;
							end case;
						when err =>
							mot_speed <= 100;
							if key_pressed = '1' and key_data = 14 then
								mode <= idle;
							end if;
					end case;
				when bonus =>
					case bonus_mode is
						when move =>
							seg_data <= to_string(can_use_energy, 9999, 10, 4) & "    ";
							data_g <= (others => (others => '0'));
							data_g(dot_y)(dot_x) <= '1';
							if bonus1_flag = '0' then
								data_r(1)(1) <= '1';
								data_g(1)(1) <= '1';
							elsif bonus1_flag = '1' and (dot_x /= 1 or dot_y /= 1) then
								data_r(1)(1) <= '0';
								data_g(1)(1) <= '0';
							end if;
							if bonus2_flag = '0' then
								data_r(1)(6) <= '1';
								data_g(1)(6) <= '1';
							elsif bonus2_flag = '1' and (dot_x /= 6 or dot_y /= 1) then
								data_r(1)(6) <= '0';
								data_g(1)(6) <= '0';
							end if;
							if bonus3_flag = '0' then
								data_r(6)(6) <= '1';
								data_g(6)(6) <= '1';
							elsif bonus3_flag = '1' and (dot_x /= 6 or dot_y /= 6) then
								data_r(6)(6) <= '0';
								data_g(6)(6) <= '0';
							end if;
							if key_pressed = '1' then
								if key_data = 1 then
									if dot_y /= 7 then
										dot_y <= dot_y + 1;
									else
										dot_y <= dot_y;
									end if;
								elsif key_data = 9 then
									if dot_y /= 0 then
										dot_y <= dot_y - 1;
									else
										dot_y <= dot_y;
									end if;
								elsif key_data = 4 then
									if dot_x /= 0 then
										dot_x <= dot_x - 1;
									else
										dot_x <= dot_x;
									end if;
								elsif key_data = 6 then
									if dot_x /= 7 then
										dot_x <= dot_x + 1;
									else
										dot_x <= dot_x;
									end if;
								elsif key_data = 12 then
									bonus_mode <= stop;
								end if;
							end if;
							if bonus1_flag = '0' and dot_x = 1 and dot_y = 1 then
								can_use_energy <= can_use_energy + 100;
								data_r(1)(1) <= '0';
								bonus1_flag <= '1';
							elsif bonus2_flag = '0' and dot_x = 6 and dot_y = 1 then
								can_use_energy <= can_use_energy + 100;
								data_r(1)(6) <= '0';
								bonus2_flag <= '1';
							elsif bonus3_flag = '0' and dot_x = 6 and dot_y = 6 then
								can_use_energy <= can_use_energy + 100;
								data_r(6)(6) <= '0';
								bonus3_flag <= '1';
							end if;
						when stop =>
							led_r <= '1';
							led_g <= '1';
							led_y <= '1';
							if key_pressed = '1' and key_data = 14 then
								mode <= idle;
							end if;
					end case;
			end case;
		end if;
	end process;

end arch;

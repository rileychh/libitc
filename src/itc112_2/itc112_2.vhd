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
	type mode_t is (res, idle, energy_for, produce, bonus);
	signal mode : mode_t;
	type produce_mode_t is (sun, water, fan, all_done);
	signal produce_mode : produce_mode_t;
	type uart_t is (idle, check, success, err, send);
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
	signal bonus1_flag, bonus2_flag, bonus3_flag, bonus4_flag, bonus5_flag, bonus6_flag : std_logic; -- bonus dot flag	
	signal value, sun_value, water_value, fan_value : integer range 0 to 9; --machine amount
	signal sun_flag, water_flag, fan_flag, back_flag : std_logic; -- setup flag
	signal value_1, value_10, value_100, value_1000 : integer range 0 to 9;
	signal input_value : integer range 0 to 9999; -- input_value <= value_1000 * 1000 + value_100 * 100 + value_10 * 10 + value_1;
	signal money : integer;
	signal need_energy : integer;
	signal delay_flag : std_logic;

	-- key
	signal pressed, key_pressed : std_logic;
	signal key_data : i4_t;
	signal key_pad : integer range 0 to 9;
	-- dot
	signal data_r, data_g : u8r_arr_t(0 to 7);
	signal dot_x, dot_y : integer range 0 to 7;
	constant all_clear : u8r_arr_t(0 to 7) := (x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00");
	constant dot_reset : u8r_arr_t(0 to 7) := (x"ff", x"ff", x"ff", x"ff", x"ff", x"ff", x"ff", x"ff");
	constant dot_idle : u8r_arr_t(0 to 7) := (x"18", x"7e", x"66", x"c3", x"c3", x"66", x"7e", x"18");
	constant dot_energy_for : u8r_arr_t(0 to 7) := (x"18", x"0c", x"06", x"ff", x"ff", x"06", x"0c", x"18");
	constant dot_produce_green : u8r_arr_t(0 to 7) := (x"c3", x"c3", x"c3", x"c3", x"03", x"03", x"03", x"03");
	constant dot_produce_red : u8r_arr_t(0 to 7) := (x"1b", x"1b", x"1b", x"1b", x"1b", x"1b", x"03", x"03");
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
	signal lcd_count : integer range 0 to 7;
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
	constant all_black : l_px_arr_t(1 to 12) := (black, black, black, black, black, black, black, black, black, black, black, black);
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
			data_r    => data_r,
			data_g    => data_g
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
	inter_rst <= '0' when (key_data = 3) and (key_pressed = '1') else '1';
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
			need_energy <= 0;
			delay_flag <= '0';
			money <= 500;
			produce_energy <= 0;
			lcd_count <= 0;
			buz_flag <= '0';
			buz <= '0';
			store_energy <= 20;
			can_use_energy <= 10;
			led_g <= '0';
			led_r <= '0';
			led_y <= '0';
			mode <= res;
		elsif rising_edge(clk) then
			case mode is
				when res =>
					led_g <= '0';
					led_r <= '0';
					led_y <= '0';
					data_g <= dot_reset;
					data_r <= dot_reset;
					mot_dir <= '0';
					mot_speed <= 0;
					lcd_con <= '0';
					lcd_clear <= '1';
					bg_color <= white;
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
					rgb <= "000";
					mot_speed <= 0;
					led_g <= '0';
					led_r <= '0';
					led_y <= '0';
					data_g <= dot_idle;
					data_r <= all_clear;
					timer_ena <= '0';
					if key_pressed = '1' and key_data = 11 then
						seg_data <= to_string(can_use_energy, 99, 10, 2) & to_string(store_energy, 99, 10, 2) & "    ";
						if sw(0 to 2) = "100" then
							back_flag <= '0';
							sun_flag <= '0';
							water_flag <= '0';
							fan_flag <= '0';
							lcd_count <= 0;
							value <= 0;
							buz_flag <= '1';
							uart_mod <= idle;
							mode <= energy_for;
						elsif sw(0 to 2) = "010" then
							produce_mode <= sun;
							sun_value <= 0;
							water_value <= 0;
							fan_value <= 0;
							mode <= produce;
							pass_str <= "    ";
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
							bonus4_flag <= '0';
							bonus5_flag <= '0';
							bonus6_flag <= '0';
							mode <= bonus;
						end if;
					else
						if sw(0 to 2) = "100" then
							seg_data <= to_string(can_use_energy, 99, 10, 2) & to_string(store_energy, 99, 10, 2) & "SUPP";
						elsif sw(0 to 2) = "010" then
							seg_data <= to_string(can_use_energy, 99, 10, 2) & to_string(store_energy, 99, 10, 2) & "DIST";
						elsif sw(0 to 2) = "001" then
							seg_data <= to_string(can_use_energy, 99, 10, 2) & to_string(store_energy, 99, 10, 2) & " BUY";
						else
							seg_data <= to_string(can_use_energy, 99, 10, 2) & to_string(store_energy, 99, 10, 2) & "    ";
						end if;
						lcd_clear <= '1';
					end if;
				when energy_for =>
					seg_data <= to_string(can_use_energy, 99, 10, 2) & to_string(store_energy, 99, 10, 2) & to_string(money, 9999, 10, 4);
					data_g <= dot_energy_for;
					data_r <= dot_energy_for;
					case uart_mod is
						when idle =>
							uart_mod <= send;
						when send =>
							if rx_done = '1' then
								if to_integer(rx_data) = 13 then
									tx_ena <= '0';
									count <= 0;
									uart_mod <= check;
									need_energy <= value_10 * 10 + value_1;
								else
									-- tx_ena <= '0';
									value_1 <= to_integer(rx_data);
									value_10 <= value_1;
								end if;
							end if;
						when check =>
							seg_data <= to_string(can_use_energy, 99, 10, 2) & to_string(store_energy, 99, 10, 2) & to_string(money, 9999, 10, 4);
							if need_energy <= can_use_energy then
								delay_flag <= '1';
								uart_mod <= success;
								rgb <= "010";
								data_r <= all_clear;
								data_g <= dot_energy_for;
								store_energy <= store_energy + can_use_energy - need_energy;
								can_use_energy <= 0;
								money <= money + need_energy * 100;
							elsif need_energy > can_use_energy and need_energy <= (store_energy + can_use_energy) then
								delay_flag <= '1';
								uart_mod <= success;
								data_r <= all_clear;
								data_g <= dot_energy_for;
								rgb <= "110";
								store_energy <= store_energy - (need_energy - can_use_energy);
								can_use_energy <= 0;
								money <= money + need_energy * 100;
							elsif need_energy > (store_energy + can_use_energy) then
								uart_mod <= err;
								buz_flag <= '1';
								rgb <= "100";
								data_r <= dot_energy_for;
								data_g <= all_clear;
							end if;
						when success =>
							data_g <= dot_energy_for;
							data_r <= all_clear;
							seg_data <= to_string(can_use_energy, 99, 10, 2) & to_string(store_energy, 99, 10, 2) & to_string(money, 9999, 10, 4);
							if delay_flag = '1' then
								if msec <= 1000 then
									timer_ena <= '1';
								else
									timer_ena <= '0';
									delay_flag <= '0';
								end if;
							else
								if key_pressed = '1' and key_data = 11 then
									mode <= idle;
								end if;
							end if;
						when err =>
							seg_data <= to_string(can_use_energy, 99, 10, 2) & to_string(store_energy, 99, 10, 2) & to_string(money, 9999, 10, 4);
							data_r <= dot_energy_for;
							data_g <= all_clear;
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
								if key_pressed = '1' and key_data = 11 then
									mode <= idle;
								end if;
							end if;
					end case;
				when produce =>
					seg_data <= to_string(can_use_energy, 99, 10, 2) & to_string(store_energy, 99, 10, 2) & "  " & to_string(produce_energy, 99, 10, 2);
					data_g <= dot_produce_green;
					data_r <= dot_produce_red;
					case produce_mode is
						when sun =>
							if key_pressed = '1' then
								sun_value <= key_pad;
							end if;
							if key_pressed = '1' and key_data = 11 then
								if sw(1) = '1' then
									produce_energy <= sun_value * 2;
									led_g <= '1';
									led_r <= '1';
									led_y <= '1';
								else
									led_g <= '0';
									led_r <= '0';
									led_y <= '0';
									produce_energy <= sun_value * 1;
								end if;
								sun_flag <= '1';
								produce_mode <= water;
							end if;
						when water =>
							if key_pressed = '1' then
								water_value <= key_pad;
							end if;
							if key_pressed = '1' and key_data = 11 then
								led_g <= '0';
								led_r <= '0';
								led_y <= '0';
								produce_energy <= produce_energy + water_value * 4;
								water_flag <= '1';
								produce_mode <= fan;
							end if;
						when fan =>
							if key_pressed = '1' then
								fan_value <= key_pad;
							end if;
							if key_pressed = '1' and key_data = 11 then
								if sw(1) = '1' then
									mot_speed <= 100;
									produce_energy <= produce_energy + fan_value * 3;
								else
									mot_speed <= 50;
									produce_energy <= produce_energy + fan_value * 1;
								end if;
								fan_flag <= '1';
								produce_mode <= all_done;
								back_flag <= '0';
							end if;
						when all_done =>
							if key_pressed = '1' and key_data = 12 and back_flag = '0' then
								can_use_energy <= can_use_energy + produce_energy;
								produce_energy <= 0;
								seg_data <= to_string(can_use_energy, 99, 10, 2) & to_string(produce_energy, 99, 10, 2) & "  " & to_string(produce_energy, 99, 10, 2);
								back_flag <= '1';
							elsif key_pressed = '1' and key_data = 11 and back_flag = '1' then
								mode <= idle;
							end if;
					end case;
					case lcd_count is
						when 0 => -- white
							x <= 5;
							lcd_con <= '0';
							lcd_clear <= '1';
							bg_color <= white;
							if draw_done = '1' then
								lcd_count <= 1;
								font_start <= '0';
								text_color <= all_black;
							end if;
						when 1 =>
							bg_color <= white;
							lcd_clear <= '0';
							y <= 10;
							text_data <= " SO    " & to_string(sun_value, sun_value'high, 10, 1) & "    ";
							font_start <= '1';
							if draw_done = '1' then
								font_start <= '0';
								lcd_count <= 2;
							end if;
						when 2 =>
							y <= 50;
							text_data <= " WA    " & to_string(water_value, water_value'high, 10, 1) & "    ";
							font_start <= '1';
							if draw_done = '1' then
								font_start <= '0';
								lcd_count <= 3;
							end if;
						when 3 =>
							y <= 90;
							text_data <= " WI    " & to_string(fan_value, fan_value'high, 10, 1) & "    ";
							font_start <= '1';
							if draw_done = '1' then
								font_start <= '0';
								lcd_count <= 1;
							end if;
						when 4 =>
						when 5 =>
						when 6 =>
						when 7 =>
					end case;
				when bonus =>
					case bonus_mode is
						when move =>
							seg_data <= to_string(can_use_energy, 99, 10, 2) & to_string(store_energy, 99, 10, 2) & to_string(money, 9999, 10, 4);
							data_g <= (others => (others => '0'));
							data_g(dot_y)(dot_x) <= '1';
							if bonus1_flag = '0' then
								data_r(3)(1) <= '1';
								data_g(3)(1) <= '1';
							elsif bonus1_flag = '1' and (dot_x /= 1 and dot_y /= 3) then
								data_r(3)(1) <= '0';
								data_g(3)(1) <= '0';
							end if;
							if bonus2_flag = '0' then
								data_r(5)(3) <= '1';
								data_g(5)(3) <= '1';
							elsif bonus2_flag = '1' and (dot_x /= 3 and dot_y /= 5) then
								data_r(5)(3) <= '0';
								data_g(5)(3) <= '0';
							end if;
							if bonus3_flag = '0' then
								data_r(2)(6) <= '1';
								data_g(2)(6) <= '1';
							elsif bonus3_flag = '1' and (dot_x /= 6 and dot_y /= 2) then
								data_r(2)(6) <= '0';
								data_g(2)(6) <= '0';
							end if;
							if bonus4_flag = '0' then
								data_g(6)(6) <= '0';
								data_r(6)(6) <= '1';
							elsif bonus4_flag = '1' and (dot_x /= 6 and dot_y /= 6) then
								data_r(6)(6) <= '0';
							end if;
							if bonus5_flag = '0' then
								data_g(3)(4) <= '0';
								data_r(3)(4) <= '1';
							elsif bonus5_flag = '1' and (dot_x /= 4 and dot_y /= 3) then
								data_r(3)(4) <= '0';
							end if;
							if bonus6_flag = '0' then
								data_g(1)(2) <= '0';
								data_r(1)(2) <= '1';
							elsif bonus6_flag = '1' and (dot_x /= 2 and dot_y /= 1) then
								data_r(1)(2) <= '0';
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
									mot_speed <= 50;
								end if;
							end if;
							if bonus1_flag = '0' and dot_x = 1 and dot_y = 3 then
								data_r(3)(1) <= '0';
								if money >= 1000 then
									bonus1_flag <= '1';
									money <= money - 1000;
									can_use_energy <= can_use_energy + 2;
								else
									bonus1_flag <= '0';
								end if;
							elsif bonus2_flag = '0' and dot_x = 3 and dot_y = 5 then
								data_r(5)(3) <= '0';
								if money >= 1000 then
									bonus2_flag <= '1';
									money <= money - 1000;
									can_use_energy <= can_use_energy + 2;
								else
									bonus2_flag <= '0';
								end if;
							elsif bonus3_flag = '0' and dot_x = 6 and dot_y = 2 then
								data_r(2)(6) <= '0';
								if money >= 1000 then
									bonus3_flag <= '1';
									money <= money - 1000;
									can_use_energy <= can_use_energy + 2;
								else
									bonus3_flag <= '0';
								end if;
							elsif bonus4_flag = '0' and dot_x = 6 and dot_y = 6 then
								data_r(6)(6) <= '0';
								if money >= 1500 then
									bonus4_flag <= '1';
									money <= money - 1500;
									can_use_energy <= can_use_energy + 3;
								else
									bonus4_flag <= '0';
								end if;
							elsif bonus5_flag = '0' and dot_x = 4 and dot_y = 3 then
								data_r(3)(4) <= '0';
								if money >= 1500 then
									bonus5_flag <= '1';
									money <= money - 1500;
									can_use_energy <= can_use_energy + 3;
								else
									bonus5_flag <= '0';
								end if;
							elsif bonus6_flag = '0' and dot_x = 2 and dot_y = 1 then
								data_r(1)(2) <= '0';
								if money >= 1500 then
									bonus6_flag <= '1';
									money <= money - 1500;
									can_use_energy <= can_use_energy + 3;
								else
									bonus6_flag <= '0';
								end if;
							end if;
						when stop =>
							if key_pressed = '1' and key_data = 11 then
								mode <= idle;
							end if;
					end case;
			end case;
		end if;
	end process;

end arch;

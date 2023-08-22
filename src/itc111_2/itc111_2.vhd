library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;

entity itc111_2 is
	port (

		clk, rst_n : in std_logic;

		-- lcd
		lcd_sclk, lcd_mosi, lcd_ss_n, lcd_dc, lcd_bl, lcd_rst_n : out std_logic;

		-- sw
		sw : in u8r_t;

		-- seg
		seg_led, seg_com : out u8r_t;

		-- key
		key_row : in u4r_t;
		key_col : out u4r_t;

		--led
		rgb : out std_logic_vector(0 to 2);

		-- g r y
		led_g, led_r, led_y : out std_logic;

		--dot
		dot_red, dot_green, dot_com : out u8r_t;

		--buzzer
		buz : out std_logic;

		-- --uart
		uart_rx : in std_logic;  -- receive pin
		uart_tx : out std_logic; -- transmit pin
		dbg_b   : out u8r_t
	);
end itc111_2;

architecture arch of itc111_2 is----------------------------------------------------------------------signal

	--seg
	signal seg_data : string(1 to 8) := (others => ' ');
	signal seg_dot : u8r_t := (others => '0');

	--key
	signal pressed, pressed_i : std_logic;
	signal key : i4_t;

	--f(1khz)
	signal msec, load : i32_t;
	signal timer_ena : std_logic;

	--lcd_draw
	signal bg_color, text_color : l_px_t;
	signal addr : l_addr_t;
	signal text_size : integer range 1 to 12;
	signal data : string(1 to 12);
	signal font_start, font_busy, lcd_clear : std_logic;
	signal draw_done, draw_start : std_logic;
	signal x : integer range -5 to 159;
	signal y : integer range 0 to 159;

	--uart
	signal tx_data, rx_data : u8_t := x"00";
	signal rx_start, rx_done : std_logic;
	signal tx_ena, tx_busy, rx_busy, rx_err : std_logic;

	--clk_1hz
	signal clk_1hz, clk_2hz, time_clk, clk_f2 : std_logic;

	--8*8 dot led
	signal data_g, data_r : u8r_arr_t(0 to 7);
	signal dot_x, dot_y : integer range 0 to 7;

	------------------------------user

	--user
	signal inter_rst : std_logic;
	signal keypad : character;

	--mode
	type mode_t is (start, idle, value_add, change, p2e);
	signal mode : mode_t;

	--currency(幣種)
	type currency_t is (LIF, JOY, LOV);
	signal currency : currency_t;
	signal coco_LIF, coco_JOY, coco_LOV, coco_T : i32_t;

	--8*8 dot image
	--green
	constant guy : u8r_arr_t(0 to 7) := (x"e0", x"40", x"00", x"00", x"00", x"00", x"00", x"00");

	--red
	constant enemy : u8r_arr_t(0 to 7) := (x"00", x"00", x"00", x"00", x"00", x"00", x"db", x"db");

	constant dot_clear : u8r_arr_t(0 to 7) := (x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00");
	constant dot_full : u8r_arr_t(0 to 7) := (x"ff", x"ff", x"ff", x"ff", x"ff", x"ff", x"ff", x"ff");
	constant dot_value_add : u8r_arr_t(0 to 7) := (x"40", x"e0", x"71", x"3b", x"1f", x"0f", x"1f", x"3f");
	constant dot_change : u8r_arr_t(0 to 7) := (x"00", x"24", x"fe", x"25", x"7e", x"a4", x"7f", x"24");

	--value_add
	signal sped : integer range 0 to 3;
	signal lcd_count : integer range 0 to 10;--lcd's state
	signal count : integer range 0 to 50;--just a signal :p
	signal pass : u8_arr_t(0 to 3);--rx's data
	signal pass_str : string(1 to 4);--software pass
	signal password : string(1 to 4);--key pass
	type add_t is (idle, speed, stop, plus, finish_add);
	signal add : add_t;

	--change
	type exchange_t is (idle, setup, number, success, err, chack, confirm, show);
	signal exchange : exchange_t;
	signal set_money : string(1 to 4);-- money string
	signal key_number : integer range 0 to 9999 := 0;--Q1000+Q100+Q10+Q1
	signal Q1000, Q100, Q10, Q1 : integer range 0 to 9999 := 0;--個十百千

	--P2E
	type Play_to_earn_t is (idle, show, shoot, clear_enemy, end_game);
	signal Play : Play_to_earn_t;
	signal end_flag, game_done : std_logic;--end game moment
	signal enemy_1, enemy_2, enemy_3 : std_logic;

begin--------------------------------------------begin packages
	clk_inst1 : entity work.clk(arch)
		generic map(
			freq => 1
		)
		port map(
			clk_in  => clk,
			rst_n   => rst_n,
			clk_out => clk_1hz
		);
	clk_inst2 : entity work.clk(arch)
		generic map(
			freq => 2
		)
		port map(
			clk_in  => clk,
			rst_n   => rst_n,
			clk_out => clk_2hz
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
	seg_inst : entity work.seg(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			seg_led => seg_led,
			seg_com => seg_com,
			data    => seg_data,
			dot     => seg_dot
		);
	key_inst : entity work.key(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			key_row => key_row,
			key_col => key_col,
			pressed => pressed_i,
			key     => key
		);

	timer_inst : entity work.timer(arch)
		port map(
			clk   => clk,
			rst_n => rst_n,
			ena   => timer_ena,
			load  => load,
			msec  => msec
		);

	edge_inst_key : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => pressed_i,
			rising  => pressed,
			falling => open
		);

	edge_inst_lcd_done : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => font_busy,
			rising  => draw_start,
			falling => draw_done
		);
	edge_inst_1hz : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => clk_1hz,
			rising  => time_clk,
			falling => open
		);
	edge_inst_2hz : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => clk_2hz,
			rising  => clk_f2,
			falling => open
		);
	edge_inst_uart : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => rx_busy,
			rising  => rx_start,
			falling => rx_done
		);
	edge_inst_end_flag : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => end_flag,
			rising  => game_done,
			falling => open
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
	gen_font_inst : entity work.gen_font(arch)
		port map(
			clk        => clk,
			rst_n      => rst_n,
			x          => x,
			y          => y,
			font_start => font_start,
			font_busy  => font_busy,
			text_size  => text_size,
			data       => data,
			text_color => text_color,
			addr       => addr,
			bg_color   => bg_color,
			clear      => lcd_clear,
			lcd_sclk   => lcd_sclk,
			lcd_mosi   => lcd_mosi,
			lcd_ss_n   => lcd_ss_n,
			lcd_dc     => lcd_dc,
			lcd_bl     => lcd_bl,
			lcd_rst_n  => lcd_rst_n

		);

	-------------------------------------------end packages
	inter_rst <= '0' when (key = 3) and (pressed = '1') else '1';
	keypad <= --key number to char
		'1' when (pressed = '1') and (key = 0) else
		'2' when (pressed = '1') and (key = 1) else
		'3' when (pressed = '1') and (key = 2) else
		'4' when (pressed = '1') and (key = 4) else
		'5' when (pressed = '1') and (key = 5) else
		'6' when (pressed = '1') and (key = 6) else
		'7' when (pressed = '1') and (key = 8) else
		'8' when (pressed = '1') and (key = 9) else
		'9' when (pressed = '1') and (key = 10)else
		'0' when (pressed = '1') and (key = 13);
	process (clk, rst_n, inter_rst)
	begin
		if rst_n = '0' or inter_rst = '0' then
			seg_data <= "        ";
			seg_dot <= x"00";
			rgb <= "000";
			timer_ena <= '0';
			font_start <= '0';
			load <= 0;
			mode <= start;
			bg_color <= white;
			lcd_clear <= '1';
			Play <= idle;
			data_g <= dot_clear;
			data_r <= dot_clear;
			pass <= (others => x"00");
			set_money <= "0000";
			password <= "    ";
			tx_ena <= '0';
		elsif rising_edge(clk) then
			case mode is
				when start => -- start state
					coco_LIF <= 1000;
					coco_JOY <= 1000;
					coco_LOV <= 1000;
					coco_T <= 0;
					lcd_clear <= '0';
					timer_ena <= '1';
					rgb <= "000";
					----------------------------dot 掃描
					data_g <= dot_full;
					data_r <= dot_full;
					----------------------------show LED RGB
					case msec is
						when 0 to 1000 => --R
							led_r <= '1';
						when 1001 to 2000 => --G
							led_g <= '1';
						when 2001 to 3000 => --B
							led_y <= '1';
						when 3001 to 4000 => null;
						when others => -- clear timer
							rgb <= "000";
							lcd_clear <= '0';
							bg_color <= white;
							mode <= idle;
							load <= 0;
							timer_ena <= '0';
					end case;
					if msec <= 250 then
						buz <= '1';
					elsif msec <= 500 then
						buz <= '0';
					elsif msec <= 750 then
						buz <= '1';
					elsif msec > 751 then
						buz <= '0';
					end if;
					----------------------------LCD
					case lcd_count is --show LCD
						when 0 =>
							if y < y'high then
								if font_busy = '0' then
									font_start <= '1';
								end if;
								if draw_done = '1' then
									font_start <= '0';
									y <= y + 1;
								end if;
							else
								lcd_clear <= '1';
								lcd_count <= 1;
							end if;
						when others =>
							lcd_count <= 0;
					end case;
				when idle => --chose mode
					--clear before state flag
					timer_ena <= '1';
					seg_dot <= x"00";
					bg_color <= white;
					text_color <= black;
					lcd_clear <= '0';
					led_g <= '0';
					led_r <= '0';
					led_y <= '0';
					rgb <= "000";
					seg_data <= "        ";
					data_g <= dot_full;
					data_r <= dot_clear;
					if pressed = '1' and key = 11 then --if change mode
						rgb <= "000";
						case sw(0 to 3) is
							when "1000" => --value_add
								rgb <= "100";
								led_r <= '0';
								led_g <= '0';
								led_y <= '0';
								dot_x <= 0;
								dot_y <= 0;
								timer_ena <= '0';
								load <= 0;
								font_start <= '0';
								pass <= (others => x"00");
								seg_data <= "00000000";
								seg_dot <= x"00";
								data_g <= dot_clear;
								data_r <= dot_full;
								lcd_clear <= '1';
								lcd_count <= 0;
								add <= idle;
								mode <= value_add;
							when "1100" => --change
								rgb <= "010";
								led_r <= '0';
								led_g <= '0';
								led_y <= '0';
								dot_x <= 0;
								dot_y <= 0;
								timer_ena <= '0';
								load <= 0;
								mode <= change;
								seg_data <= "00000000";
								seg_dot <= x"00";
								data_g <= dot_change;
								data_r <= dot_change;
								lcd_clear <= '1';
								lcd_count <= 0;
								exchange <= idle;--(idle,setup,confirm);
							when "1110" => --p2e
								rgb <= "001";
								dot_x <= 0;
								dot_y <= 0;
								seg_data <= "00000000";
								seg_dot <= x"00";
								data_g <= dot_clear;
								data_r <= dot_clear;
								lcd_clear <= '1';
								lcd_count <= 0;
								mode <= p2e;
								Play <= idle;
							when others =>
								seg_data <= "        ";
								seg_dot <= x"00";
								data_g <= dot_clear;
								data_r <= dot_clear;
								lcd_clear <= '1';
								mode <= idle;
						end case;
					end if;
					case sw(0 to 3) is
						when "1000" => --value_add
							seg_data <= "    PLUS";
						when "1100" => --change
							seg_data <= "    SELL";
						when "1110" => --p2e
							seg_data <= "     P2E";
						when others =>
							seg_data <= "        ";
					end case;
				when value_add => --coco ++
					case add is
						when idle => --chose coco
							data_g <= dot_value_add;
							data_r <= dot_value_add;
							lcd_clear <= '0';
							seg_data <= "00000000";
							if pressed = '1' and key = 11 then--choise coco
								case sw(0 to 3) is
									when "1000" =>
										currency <= LIF;
									when "1100" =>
										currency <= JOY;
									when "1110" =>
										currency <= LOV;
									when others => null;
								end case;
								lcd_count <= 0;
								add <= speed;
							end if;
						when speed => --choise speed
							case currency is
								when LIF =>
									seg_data <= "0000" & to_string(coco_LIF, 3000, 10, 4);
								when JOY =>
									seg_data <= "0000" & to_string(coco_JOY, 3000, 10, 4);
								when LOV =>
									seg_data <= "0000" & to_string(coco_LOV, 3000, 10, 4);
							end case;
							if pressed = '1' then
								if key = 0 then
									sped <= 1;
								elsif key = 1 then
									sped <= 2;
								elsif key = 2 then
									sped <= 3;
								end if;
							end if;
							case lcd_count is
								when 0 =>
									y <= 20;
									case currency is
										when LIF =>
											data <= "   L  I  F  ";
										when JOY =>
											data <= "   J  O  Y  ";
										when LOV =>
											data <= "   L  O  V  ";
										when others =>
											data <= "            ";
									end case;
									font_start <= '1';
									if draw_done = '1' then
										font_start <= '0';
										y <= 70;
										lcd_count <= 1;
									end if;
								when 1 =>
									data <= "         " & to_string(sped, 3, 10, 1) & "  ";
									font_start <= '1';
									if draw_done = '1' then
										font_start <= '0';
										y <= 0;
										lcd_count <= 0;
									end if;
								when others => null;
							end case;
							if pressed = '1' and key = 11 then
								add <= plus;
							end if;
						when plus => --if password correct
							data_g <= dot_value_add;
							data_r <= dot_clear;
							-- Money add
							if time_clk = '1' then
								case currency is
									when LIF =>
										if coco_LIF >= 3000 then
											coco_LIF <= 3000;
											add <= finish_add;
										else
											if sped = 3 then
												coco_LIF <= coco_LIF + 500;
											elsif sped = 2 then
												coco_LIF <= coco_LIF + 250;
											elsif sped = 1 then
												coco_LIF <= coco_LIF + 100;
											end if;
										end if;
									when JOY =>
										if coco_JOY >= 3000 then
											coco_JOY <= 3000;
											add <= finish_add;
										else
											if sped = 3 then
												coco_JOY <= coco_JOY + 500;
											elsif sped = 2 then
												coco_JOY <= coco_JOY + 250;
											elsif sped = 1 then
												coco_JOY <= coco_JOY + 100;
											end if;
										end if;
									when LOV =>
										if coco_LOV >= 3000 then
											coco_LOV <= 3000;
											add <= finish_add;
										else
											if sped = 3 then
												coco_LOV <= coco_LOV + 500;
											elsif sped = 2 then
												coco_LOV <= coco_LOV + 250;
											elsif sped = 1 then
												coco_LOV <= coco_LOV + 100;
											end if;
										end if;
								end case;
							end if;
							--Seg Show coco
							case currency is
								when LIF =>
									seg_data <= "0000" & to_string(coco_LIF, 3000, 10, 4);
								when JOY =>
									seg_data <= "0000" & to_string(coco_JOY, 3000, 10, 4);
								when LOV =>
									seg_data <= "0000" & to_string(coco_LOV, 3000, 10, 4);
								when others =>
									data <= "            ";
							end case;
							--interrupt
							if pressed = '1' and key = 12 then
								password <= "    ";
								seg_data <= "        ";
								lcd_clear <= '1';
								add <= stop;
							end if;
						when stop => -- if password errol
							if pressed = '1' and key = 11 then
								mode <= idle;
							end if;
						when finish_add => --when add money upper limit
							data_g <= dot_clear;
							data_r <= dot_value_add;
							if pressed = '1' and key = 11 then
								mode <= idle;
								lcd_clear <= '1';
							end if;
						when others => null;
					end case;
				when change => --others coco to T_coco......
					case exchange is
						when idle => --start setup
							seg_data <= "00000000";
							lcd_clear <= '1';
							font_start <= '0';
							Q1 <= 0;
							Q10 <= 0;
							Q100 <= 0;
							Q1000 <= 0;
							set_money <= "0000";
							key_number <= 0;
							--choose coco
							if pressed = '1' and key = 11 then
								data_g <= dot_change;
								data_r <= dot_clear;
								case sw(0 to 3) is
									when "1000" =>
										currency <= LIF;
									when "1100" =>
										currency <= JOY;
									when "1110" =>
										currency <= LOV;
									when others => null;
								end case;
								exchange <= setup;
							end if;
						when setup => --input password
							case currency is
								when LIF =>
									seg_data <= "0000" & to_string(coco_LIF, 9999, 10, 4);
								when JOY =>
									seg_data <= "0000" & to_string(coco_JOY, 9999, 10, 4);
								when LOV =>
									seg_data <= "0000" & to_string(coco_LOV, 9999, 10, 4);
								when others => null;
							end case;
							if rx_done = '1' then --接收軟體資料
								if to_integer(rx_data) = 13 then
									tx_ena <= '0';
									count <= 0;
									lcd_count <= 0;
									exchange <= chack;
								else
									tx_ena <= '0';
									pass(count) <= rx_data;
									count <= count + 1;
								end if;
							end if;
							pass_str <= to_string(to_integer(pass(0)) - 48, 9, 10, 1) & to_string(to_integer(pass(1)) - 48, 9, 10, 1) & to_string(to_integer(pass(2)) - 48, 9, 10, 1) & to_string(to_integer(pass(3)) - 48, 9, 10, 1);
						when chack => --chack password true or not
							if pass_str = "1234" then
								exchange <= success;
							else
								exchange <= err;
							end if;
						when success => --input set_money
							if key < 14 and key /= 3 and key /= 7 and key /= 11 and key /= 12 and pressed = '1' then
								set_money <= set_money(2 to 4) & keypad;
							end if;
							case currency is
								when LIF =>
									seg_data <= set_money & to_string(coco_LIF, 3000, 10, 4);
								when JOY =>
									seg_data <= set_money & to_string(coco_JOY, 3000, 10, 4);
								when LOV =>
									seg_data <= set_money & to_string(coco_LOV, 3000, 10, 4);
								when others => null;
							end case;
							case set_money(1) is
								when '1' =>
									Q1000 <= 1000;
								when '2' =>
									Q1000 <= 2000;
								when '3' =>
									Q1000 <= 3000;
								when '4' =>
									Q1000 <= 4000;
								when '5' =>
									Q1000 <= 5000;
								when '6' =>
									Q1000 <= 6000;
								when '7' =>
									Q1000 <= 7000;
								when '8' =>
									Q1000 <= 8000;
								when '9' =>
									Q1000 <= 9000;
								when others =>
									Q1000 <= 0;
							end case;
							case set_money(2) is
								when '1' =>
									Q100 <= 100;
								when '2' =>
									Q100 <= 200;
								when '3' =>
									Q100 <= 300;
								when '4' =>
									Q100 <= 400;
								when '5' =>
									Q100 <= 500;
								when '6' =>
									Q100 <= 600;
								when '7' =>
									Q100 <= 700;
								when '8' =>
									Q100 <= 800;
								when '9' =>
									Q100 <= 900;
								when others =>
									Q100 <= 0;
							end case;
							case set_money(3) is
								when '1' =>
									Q10 <= 10;
								when '2' =>
									Q10 <= 20;
								when '3' =>
									Q10 <= 30;
								when '4' =>
									Q10 <= 40;
								when '5' =>
									Q10 <= 50;
								when '6' =>
									Q10 <= 60;
								when '7' =>
									Q10 <= 70;
								when '8' =>
									Q10 <= 80;
								when '9' =>
									Q10 <= 90;
								when others =>
									Q10 <= 0;
							end case;
							case set_money(4) is
								when '1' =>
									Q1 <= 1;
								when '2' =>
									Q1 <= 2;
								when '3' =>
									Q1 <= 3;
								when '4' =>
									Q1 <= 4;
								when '5' =>
									Q1 <= 5;
								when '6' =>
									Q1 <= 6;
								when '7' =>
									Q1 <= 7;
								when '8' =>
									Q1 <= 8;
								when '9' =>
									Q1 <= 9;
								when others =>
									Q1 <= 0;
							end case;
							if pressed = '1' and key = 11 then
								exchange <= number;
							end if;
							data_g <= dot_change;
							data_r <= dot_clear;
						when err => --password is error
							case currency is
								when LIF =>
									seg_data <= set_money & to_string(coco_LIF, 3000, 10, 4);
								when JOY =>
									seg_data <= set_money & to_string(coco_JOY, 3000, 10, 4);
								when LOV =>
									seg_data <= set_money & to_string(coco_LOV, 3000, 10, 4);
								when others => null;
							end case;
							if pressed = '1' and key = 11 then
								mode <= idle;
							end if;
							data_g <= dot_clear;
							data_r <= dot_change;
						when number => --add Q1000 Q100 Q10 Q1
							key_number <= Q1000 + Q100 + Q10 + Q1;
							exchange <= confirm;
						when confirm => --exchange rate
							if key_number <= coco_LIF then
								case currency is
									when LIF =>
										coco_LIF <= coco_LIF - key_number;
										coco_T <= key_number * 3 + coco_T;
										exchange <= show;
									when JOY =>
										coco_JOY <= coco_JOY - key_number;
										coco_T <= key_number * 2 + coco_T;
										exchange <= show;
									when LOV =>
										coco_LOV <= coco_LOV - key_number;
										coco_T <= key_number * 1 + coco_T;
										exchange <= show;
									when others => null;
								end case;
							else
								case currency is
									when LIF =>
										coco_T <= coco_LIF * 3;
										coco_LIF <= 0;
										exchange <= show;
									when JOY =>
										coco_T <= key_number * 2;
										coco_JOY <= 0;
										exchange <= show;
									when LOV =>
										coco_T <= key_number * 1;
										coco_LOV <= 0;
										exchange <= show;
									when others => null;
								end case;
							end if;
						when show => -- show money's data on seg
							lcd_clear <= '0';
							set_money <= "0000";
							------------------------seg
							case currency is
								when LIF =>
									seg_data <= to_string(coco_T, 9999, 10, 4) & to_string(coco_LIF, 3000, 10, 4);
								when JOY =>
									seg_data <= to_string(coco_T, 9999, 10, 4) & to_string(coco_JOY, 3000, 10, 4);
								when LOV =>
									seg_data <= to_string(coco_T, 9999, 10, 4) & to_string(coco_LOV, 3000, 10, 4);
								when others => null;
							end case;
							data_g <= dot_clear;
							data_r <= dot_change;
							if pressed = '1' and key = 11 then--mode back to idle
								mode <= idle;
							end if;
						when others => null;
					end case;
				when p2e => --play to earn
					case Play is
						when idle =>

							seg_data <= "00000000";
							data_g <= guy;
							data_r <= enemy;
							dot_x <= 0;
							dot_y <= 2;
							enemy_1 <= '1';
							enemy_2 <= '1';
							enemy_3 <= '1';
							if pressed = '1' and key = 11 then
								case sw(0 to 3) is
									when "1000" =>
										currency <= LIF;
									when "1100" =>
										currency <= JOY;
									when "1110" =>
										currency <= LOV;
									when others => null;
								end case;
								Play <= show;
								timer_ena <= '0';
								end_flag <= '0';
								load <= 0;
							end if;
						when show =>
							if enemy_1 = '0' and enemy_2 = '0' and enemy_3 = '0'then
								play <= end_game;
								end_flag <= '1';
							end if;
							data_r(6)(2) <= '0';
							data_r(7)(2) <= '0';
							data_r(6)(5) <= '0';
							data_r(7)(5) <= '0';

							data_g <= (others => (others => '0'));
							data_g(0)(dot_x) <= '1';
							data_g(0)(dot_x + 1) <= '1';
							data_g(0)(dot_x + 2) <= '1';
							data_g(1)(dot_x + 1) <= '1';
							if pressed = '1' and key = 5 then
								Play <= shoot;
							end if;
							if pressed = '1' and key = 4 then
								if dot_x <= 0 then
									dot_x <= 0;
								else
									dot_x <= dot_x - 1;
								end if;
							end if;
							if pressed = '1' and key = 6 then
								if dot_x >= 5 then
									dot_x <= 5;
								else
									dot_x <= dot_x + 1;
								end if;
							end if;
							case currency is
								when LIF =>
									seg_data <= "0000" & to_string(coco_LIF, 3000, 10, 4);
								when JOY =>
									seg_data <= "0000" & to_string(coco_JOY, 3000, 10, 4);
								when LOV =>
									seg_data <= "0000" & to_string(coco_LOV, 3000, 10, 4);
								when others => null;
							end case;
						when shoot =>
							data_g <= (others => (others => '0'));

							data_g(0)(dot_x) <= '1';
							data_g(0)(dot_x + 1) <= '1';
							data_g(0)(dot_x + 2) <= '1';
							data_g(1)(dot_x + 1) <= '1';

							data_g(dot_y)(dot_x + 1) <= '1';
							data_r(dot_y)(dot_x + 1) <= '1';
							data_r(dot_y - 1)(dot_x + 1) <= '0';

							if clk_f2 = '1' then
								if (dot_x = 1 or dot_x = 4) then
									dot_y <= dot_y + 1;
									if dot_y = 7 then
										dot_y <= 2;
										end_flag <= '0';
										play <= show;
									end if;
								else
									dot_y <= dot_y + 1;
									if dot_y = 5 then
										dot_y <= 2;
										end_flag <= '0';
										play <= clear_enemy;
									end if;
								end if;
							end if;
						when clear_enemy =>
							if enemy_1 = '0' and enemy_2 = '0' and enemy_3 = '0'then
								play <= end_game;
							else
								if dot_x = 0 then
									data_r(7)(0) <= '0';
									data_r(7)(1) <= '0';
									data_r(6)(0) <= '0';
									data_r(6)(1) <= '0';
									data_r(5)(0) <= '0';
									data_r(5)(1) <= '0';
									enemy_1 <= '0';
								elsif (dot_x = 2 or dot_x = 3) then
									data_r(7)(3) <= '0';
									data_r(7)(4) <= '0';
									data_r(6)(3) <= '0';
									data_r(6)(4) <= '0';
									data_r(5)(3) <= '0';
									data_r(5)(4) <= '0';
									enemy_2 <= '0';

								elsif dot_x = 5 then
									data_r(7)(7) <= '0';
									data_r(7)(6) <= '0';
									data_r(6)(7) <= '0';
									data_r(6)(6) <= '0';
									data_r(5)(7) <= '0';
									data_r(5)(6) <= '0';
									enemy_3 <= '0';

								end if;
								play <= show;
							end if;

						when end_game =>
							if game_done = '1' then
								case currency is
									when LIF =>
										coco_LIF <= coco_LIF + 100;
									when JOY =>
										coco_JOY <= coco_JOY + 100;
									when LOV =>
										coco_LOV <= coco_LOV + 100;
									when others => null;
								end case;
							end if;
							data_g <= dot_clear;
							data_r <= dot_clear;
							--show seg

							case currency is
								when LIF =>
									seg_data <= "0000" & to_string(coco_LIF, 3000, 10, 4);
								when JOY =>
									seg_data <= "0000" & to_string(coco_JOY, 3000, 10, 4);
								when LOV =>
									seg_data <= "0000" & to_string(coco_LOV, 3000, 10, 4);
								when others => null;
							end case;
							--back idle
							if pressed = '1' and key = 11 then
								mode <= idle;
								data_g <= dot_clear;
								data_r <= dot_clear;
							end if;
						when others => null;
					end case;
				when others => null;
			end case;
		end if;
	end process;
end architecture;

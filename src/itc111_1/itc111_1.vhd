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

	--dht11
	signal temp_int, hum_int : integer range 0 to 99;

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
	type mode_t is (idle, dht, lcd_show, test_all);
	signal mode : mode_t;

begin--------------------------------------------begin packages
	dht_inst : entity work.dht(arch)
		port map(
			clk      => clk,
			rst_n    => rst_n,
			temp_int => temp_int,
			temp_dec => open,
			hum_int  => hum_int,
			hum_dec  => open
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
	edge_inst_1s : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => clk_1hz,
			rising  => time_clk,
			falling => open
		);
	edge_inst_tts_done : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => tts_busy,
			rising  => open,
			falling => tts_done
		);

	edge_inst_1s : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => clk_1hz,
			rising  => time_clk,
			falling => open
		);
	edge_inst_tts_done : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => tts_busy,
			rising  => open,
			falling => tts_done
		);
	lcd_draw : entity work.gen_font(arch)
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
	process (clk, rst_n, inter_rst)
	begin
		if rst_n = '0' or inter_rst = '0' then
			seg_data <= "        ";
			seg_dot <= x"00";
		elsif rising_edge(clk) then
			--timer(10,11)
			if done = '1' and (mode = tts or mode = auto) then
				if time_clk = '1' then
					if secs = secs'high then
						secs <= 0;
						if mins = mins'high then
							mins <= 0;
						else
							mins <= mins + 1;
						end if;
					else
						secs <= secs + 1;
					end if;
				end if;
			end if;
			--stop
			if (pressed = '1') and (key = 12) then
				done <= not done;
			end if;
			--change mode
			if done = '1' then
				case sw(6 to 7) is
					when "00" => ----idle
						tts_flag <= '0';
						mode <= buff;
					when "01" => ----dht
						lcd_clear <= '1';
						tts_flag <= '0';
						seg_data <= "        ";
						dot <= "00000000";
						mode <= dht;
					when "10" => ----tts
						lcd_clear <= '1';
						tts_flag <= '1';
						mode <= tts;
					when "11" => ----auto
						lcd_clear <= '1';
						font_start <= '0';
						tts_flag <= '1';
						mode <= auto;
				end case;
			else
				mode <= stop;
			end if;

			case mode is
				when buff =>
					font_start <= '0';
					lcd_clear <= '0';
					if font_busy = '0' then
						mode <= idle;
					end if;
				when idle =>
					case lcd_count is
						when 1 => --red
							lcd_clear <= '0';
							bg_color <= red;
							if y < y'high then
								if font_busy = '0' then
									font_start <= '1';
								end if;
								if draw_done = '1' then
									font_start <= '0';
									y <= y + 1;
								end if;
							else
								time_ena <= '1';
								y <= 0;
								if y >= y'high and msec >= 500 then
									lcd_clear <= '1';
									lcd_count <= 2;
								end if;
							end if;
						when 2 => --blue
							lcd_clear <= '0';
							bg_color <= blue;
							if y < y'high then
								if font_busy = '0' then
									font_start <= '1';
								end if;
								if draw_done = '1' then
									font_start <= '0';
									y <= y + 1;
								end if;
							else
								y <= 0;
								if y >= y'high and msec >= 1000 then
									lcd_clear <= '1';
									lcd_count <= 3;
								end if;
							end if;
						when 3 => --white
							lcd_clear <= '0';
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
								lcd_clear <= '1';
								y <= 10;
								text_color <= green;
								lcd_count <= 4;
							end if;
						when 4 => --1~5
							lcd_clear <= '0';
							y <= 10;
							data <= " 1 2 3 4 5  ";
							font_start <= '1';
							if draw_done = '1' and msec >= 1500 then
								font_start <= '0';
								y <= 30;
								lcd_count <= 5;
							end if;
						when 5 => --6~0
							if y = 30 then
								data <= " 6 7 8 9 0  ";
								font_start <= '1';
							end if;
							if draw_done = '1' and msec >= 2000 then
								font_start <= '0';
								y <= 50;
								lcd_count <= 6;
							end if;
						when 6 => --Vol. On Off
							if y = 50 then
								data <= " Vol.On Off ";
								font_start <= '1';
							end if;
							if draw_done = '1' and msec >= 2500 then
								font_start <= '0';
								y <= 70;
								lcd_count <= 7;
							end if;
						when 7 => --P A N F T
							if y = 70 then
								data <= " P A N F T  ";
								font_start <= '1';
							end if;
							if draw_done = '1' and msec >= 3000 then
								font_start <= '0';
								y <= 90;
								lcd_count <= 8;
							end if;
						when 8 => --, : _ .
							if y = 90 then
								data <= " , : _ .    ";
								font_start <= '1';
							end if;
							if draw_done = '1' and msec >= 3500 then
								data <= "            ";
								font_start <= '0';
								lcd_count <= 1;
								lcd_clear <= '1';
								y <= 0;
								load <= 0;
								time_ena <= '0';
							end if;
						when others => null;
					end case;
				when dht =>
					dot <= "00100000";
					if pressed = '1' then
						case key is
							when 8 =>
								if seg_func_count < 4 then
									seg_func_count <= seg_func_count + 1;
								else
									seg_func_count <= seg_func_count;
								end if;
							when 7 =>
								if seg_func_count > 0 then
									seg_func_count <= seg_func_count - 1;
								else
									seg_func_count <= seg_func_count;
								end if;
							when others =>
						end case;
					end if;
					case seg_func_count is
						when 0 => --F0
							seg_data <= "F0 00000";
						when 1 => --F1
							seg_data <= "F1  " & to_string(temp_int, temp_int'high, 10, 2) & seg_deg & 'C';
						when 2 => --F2
							seg_data <= "F2 " & to_string(hum_int, hum_int'high, 10, 2) & seg_deg & seg_percent & 'o';
						when 3 => --F3
							seg_data <= "F3 FUnC1";
						when 4 => --F4
							seg_data <= "F4 FUnC2";
					end case;
				when tts =>
					lcd_clear <= '0';
					if pressed = '1' then--tts_play_count   tts_func_count   tts_play
						case key is
							when 9 =>
								if tts_func_count = 1 then
									tts_play_count <= 1;
								elsif tts_func_count = 2 then
									if tts_play_count < 3 then
										tts_play_count <= tts_play_count + 1;
									else
										tts_play_count <= tts_play_count;
									end if;
								else
									tts_play_count <= 0;
								end if;
							when 8 =>
								if tts_func_count = 1 then
									tts_play_count <= 1;
								elsif tts_func_count = 2 then
									if tts_play_count > 1 then
										tts_play_count <= tts_play_count - 1;
									else
										tts_play_count <= tts_play_count;
									end if;
								else
									tts_play_count <= 0;
								end if;
							when 15 =>
								if tts_func_count >= 3 then
									tts_func_count <= 2;
								else
									tts_func_count <= tts_func_count + 1;
								end if;
							when 10 =>
								-- func_count<=tts_func_count;
								-- play_count<=tts_play_count;
							when others => null;
						end case;
					end if;
					case tts_mode is
						when idle =>
							if pressed = '1' and (key = 15 or key = 10) then
								tts_mode <= tts_play;
							end if;
						when tts_play =>
							tts_ena <= '1';
							if key = 10 then
								if tts_play_count = 1 then
									len <= 5;
									txt(0 to 4) <= tts_play_file & star;
								elsif tts_play_count = 2 then
									len <= 5;
									txt(0 to 4) <= tts_play_file & tiger;
								elsif tts_play_count = 3 then
									len <= 5;
									txt(0 to 4) <= tts_play_file & bee;
								end if;
								if tts_done = '1' then
									tts_ena <= '0';
									tts_mode <= stop;
								end if;
							elsif key = 15 then
								len <= 2;
								if tts_func_count = 2 then
									txt(0 to 1) <= tts_instant_resume;
								else
									txt(0 to 1) <= tts_instant_pause;
								end if;
							end if;
							if tts_done = '1' then
								tts_ena <= '0';
								tts_mode <= stop;
							end if;
						when stop =>
							if tts_busy = '0' then
								tts_mode <= idle;
							end if;
					end case;
					case lcd_count is --lcd_count(LCD)
						when 0 => -- white
							lcd_clear <= '0';
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
									text_color <= green;
									lcd_count <= 1;
								end if;
							end if;
							lcd_clear <= '0';
						when 1 => -- F1 , N , P under line
							y <= 5;
							if tts_func_count = 0 then
								data <= "            ";
								font_start <= '1';
							elsif tts_func_count = 1 then
								data <= " __         ";
								font_start <= '1';
							elsif tts_func_count = 2 then
								data <= "      _     ";
								font_start <= '1';
							elsif tts_func_count = 3 then
								tts_ena <= '0';
								data <= "          _ ";
								font_start <= '1';
							end if;
							if draw_done = '1' then
								font_start <= '0';
								y <= 0;
								lcd_count <= 2;
							end if;
						when 2 => -- F1 , N , P
							if y = 0 and done = '1' then
								y <= 0;
							end if;
							if y = 0 then
								data <= " F1 , N , P ";
								font_start <= '1';
							end if;
							if draw_done = '1' then
								font_start <= '0';
								lcd_count <= 3;
							end if;
						when 3 => -- T1 under line
							y <= 30;
							if tts_play_count = 1 and tts_func_count = 2 then
								data <= "      ______";
							else
								data <= "            ";
							end if;
							font_start <= '1';
							if draw_done = '1' then
								font_start <= '0';
								y <= 25;
								lcd_count <= 4;
							end if;
						when 4 => -- File:T1.wav
							if y = 0 and done = '1' then
								y <= 25;
							end if;
							if y = 25 then
								x <= - 2;
								data <= "File1:T1.wav";
								font_start <= '1';
							end if;
							if draw_done = '1' then
								font_start <= '0';
								lcd_count <= 5;
							end if;
						when 5 => -- T2 under line
							y <= 55;
							if tts_play_count = 2 and tts_func_count = 2 then
								data <= "      ______";
							else
								data <= "            ";
							end if;
							font_start <= '1';
							if draw_done = '1' then
								font_start <= '0';
								y <= 50;
								lcd_count <= 6;
							end if;
						when 6 => --      T2.wav
							if y = 0 and done = '1' then
								y <= 50;
							end if;
							if y = 50 then
								data <= "      T2.wav";
								font_start <= '1';
							end if;
							if draw_done = '1' then
								font_start <= '0';
								lcd_count <= 7;
							end if;
						when 7 => -- T3 under line
							y <= 80;
							if tts_play_count = 3 and tts_func_count = 2 then
								data <= "      ______";
							else
								data <= "            ";
							end if;
							font_start <= '1';
							if draw_done = '1' then
								font_start <= '0';
								y <= 75;
								lcd_count <= 8;
							end if;
						when 8 => --      T3.wav
							if y = 0 and done = '1' then
								y <= 75;
							end if;
							if y = 75 then
								data <= "      T3.wav";
								font_start <= '1';
							end if;
							if draw_done = '1' then
								font_start <= '0';
								y <= 100;
								lcd_count <= 9;
							end if;
						when 9 => -- Vol. :05
							if y = 0 and done = '1' then
								y <= 100;
							end if;
							if y = 100 then
								data <= " Vol. :05   ";
								font_start <= '1';
							end if;
							if draw_done = '1' then
								font_start <= '0';
								y <= 120;
								lcd_count <= 10;
							end if;
						when 10 => -- Time
							if y = 0 and done = '1' then
								y <= 120;
							end if;
							if y = 120 then
								data <= " T    :" & to_string(mins, mins'high, 10, 2) & ":" & to_string(secs, secs'high, 10, 2);
								font_start <= '1';
							end if;
							if draw_done = '1' then
								data <= "            ";
								y <= 0;
								font_start <= '0';
								lcd_count <= 1;
							end if;
						when others =>
					end case;
				when auto =>
					lcd_clear <= '0';
					if pressed = '1' then--tts_play_count   tts_func_count
						case key is
							when 9 => --up
								if tts_func_count = 1 then
									tts_play_count <= 1;
								elsif tts_func_count = 2 then
									if tts_play_count < 3 then
										tts_play_count <= tts_play_count + 1;
									else
										tts_play_count <= tts_play_count;
									end if;
								else
									tts_play_count <= 0;
								end if;
							when 8 => --down
								if tts_func_count = 1 then
									tts_play_count <= 1;
								elsif tts_func_count = 2 then
									if tts_play_count > 1 then
										tts_play_count <= tts_play_count - 1;
									else
										tts_play_count <= tts_play_count;
									end if;
								else
									tts_play_count <= 0;
								end if;
							when 15 => --chose function F1,N,p 
								if tts_func_count >= 3 then
									tts_func_count <= 2;
								else
									tts_func_count <= tts_func_count + 1;
								end if;
							when 14 => --show seg data
								dot <= "00100000";
								seg_data <= "F1  " & to_string(temp_int, temp_int'high, 10, 2) & seg_deg & 'C';
							when others => null;
						end case;
					end if;
					case lcd_count is --lcd_count(LCD)
						when 0 => -- white
							lcd_clear <= '0';
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
									text_color <= green;
									lcd_count <= 1;
								end if;
							end if;
							lcd_clear <= '0';
						when 1 => -- F1 , N , P under line
							y <= 5;
							if tts_func_count = 0 then
								data <= "            ";
								font_start <= '1';
							elsif tts_func_count = 1 then
								data <= " __         ";
								font_start <= '1';
							elsif tts_func_count = 2 then
								data <= "      _     ";
								font_start <= '1';
							elsif tts_func_count = 3 then
								tts_ena <= '0';
								data <= "          _ ";
								font_start <= '1';
							end if;
							if draw_done = '1' then
								font_start <= '0';
								y <= 0;
								lcd_count <= 2;
							end if;
						when 2 => -- F1 , N , P
							if y = 0 and done = '1' then
								y <= 0;
							end if;
							if y = 0 then
								data <= " F1 , N , P ";
								font_start <= '1';
							end if;
							if draw_done = '1' then
								font_start <= '0';
								lcd_count <= 3;
							end if;
						when 3 => -- T1 under line
							y <= 30;
							if tts_play_count = 1 and tts_func_count = 2 then
								data <= "      ______";
							else
								data <= "            ";
							end if;
							font_start <= '1';
							if draw_done = '1' then
								font_start <= '0';
								y <= 25;
								lcd_count <= 4;
							end if;
						when 4 => -- File:T1.wav
							if y = 0 and done = '1' then
								y <= 25;
							end if;
							if y = 25 then
								x <= - 2;
								data <= "File1:T1.wav";
								font_start <= '1';
							end if;
							if draw_done = '1' then
								font_start <= '0';
								lcd_count <= 5;
							end if;
						when 5 => -- T2 under line
							y <= 55;
							if tts_play_count = 2 and tts_func_count = 2 then
								data <= "      ______";
							else
								data <= "            ";
							end if;
							font_start <= '1';
							if draw_done = '1' then
								font_start <= '0';
								y <= 50;
								lcd_count <= 6;
							end if;
						when 6 => --      T2.wav
							if y = 0 and done = '1' then
								y <= 50;
							end if;
							if y = 50 then
								data <= "      T2.wav";
								font_start <= '1';
							end if;
							if draw_done = '1' then
								font_start <= '0';
								lcd_count <= 7;
							end if;
						when 7 => -- T3 under line
							y <= 80;
							if tts_play_count = 3 and tts_func_count = 2 then
								data <= "      ______";
							else
								data <= "            ";
							end if;
							font_start <= '1';
							if draw_done = '1' then
								font_start <= '0';
								y <= 75;
								lcd_count <= 8;
							end if;
						when 8 => --      T3.wav
							if y = 0 and done = '1' then
								y <= 75;
							end if;
							if y = 75 then
								data <= "      T3.wav";
								font_start <= '1';
							end if;
							if draw_done = '1' then
								font_start <= '0';
								y <= 100;
								lcd_count <= 9;
							end if;
						when 9 => -- Vol. :05
							if y = 0 and done = '1' then
								y <= 100;
							end if;
							if y = 100 then
								data <= " Vol. :05   ";
								font_start <= '1';
							end if;
							if draw_done = '1' then
								font_start <= '0';
								y <= 120;
								lcd_count <= 10;
							end if;
						when 10 => -- Time
							if y = 0 and done = '1' then
								y <= 120;
							end if;
							if y = 120 then
								data <= " T    :" & to_string(mins, mins'high, 10, 2) & ":" & to_string(secs, secs'high, 10, 2);
								font_start <= '1';
							end if;
							if draw_done = '1' then
								data <= "            ";
								y <= 0;
								font_start <= '0';
								lcd_count <= 1;
							end if;
						when others =>
					end case;
					case tts_count is --tts_play
						when 0 => --交閮剖
							case tts_mode is
								when idle =>
									if pressed = '1' and key = 15 then
										tts_mode <= tts_play;
									end if;
								when tts_play =>
									tts_ena <= '1';
									if tts_func_count = 2 then
										len <= 8;
										txt(0 to 7) <= tts_setup;
									end if;
									if tts_done = '1' then
										tts_ena <= '0';
										tts_mode <= stop;
									end if;
								when stop =>
									if tts_busy = '0' then
										tts_count <= 1;
										tts_mode <= idle;
									end if;
							end case;
						when 1 => --交T1
							case tts_mode is
								when idle =>
									if pressed = '1' and (key = 15 or key = 10) then
										tts_mode <= tts_play;
									end if;
								when tts_play =>
									tts_ena <= '1';
									len <= 6;
									if key = 10 then
										if tts_play_count = 1 then
											txt(0 to 5) <= play_music1;
										elsif tts_play_count = 2 then
											txt(0 to 5) <= play_music2;
										elsif tts_play_count = 3 then
											txt(0 to 5) <= Play_music3;
										end if;
									elsif key = 15 then
										len <= 2;
										if tts_func_count = 2 then
											txt(0 to 1) <= tts_instant_resume;
										else
											txt(0 to 1) <= tts_instant_pause;
										end if;
									end if;
									if tts_done = '1' then
										tts_ena <= '0';
										tts_mode <= stop;
									end if;
								when stop =>
									if tts_busy = '0' then
										tts_count <= 2;
										tts_mode <= tts_play;
									end if;
							end case;
						when 2 => --Play File
							case tts_mode is
								when idle =>
									if pressed = '1' and (key = 15 or key = 10) then
										tts_mode <= tts_play;
									end if;
								when tts_play =>
									tts_ena <= '1';
									if key = 10 then
										if tts_play_count = 1 then
											len <= 5;
											txt(0 to 4) <= tts_play_file & star;
										elsif tts_play_count = 2 then
											len <= 5;
											txt(0 to 4) <= tts_play_file & tiger;
										elsif tts_play_count = 3 then
											len <= 5;
											txt(0 to 4) <= tts_play_file & bee;
										end if;
										if tts_done = '1' then
											tts_ena <= '0';
											tts_mode <= stop;
										end if;
										-- elsif key=15 then
										-- 	len<=2;
										-- 	if tts_func_count=2 then
										-- 		txt(0 to 1)<=tts_instant_resume;
										-- 	else
										-- 		txt(0 to 1)<=tts_instant_pause;
										-- 	end if;
									end if;
									if tts_done = '1' then
										tts_ena <= '0';
										tts_mode <= stop;
									end if;
								when stop =>
									if tts_busy = '0' then
										tts_mode <= idle;
										tts_count <= 1;
									end if;
							end case;
							----------
							-- when 3=>--play File or skip(wait pressed)
							-- 	case tts_mode is
							-- 		when idle=>
							-- 			if pressed='1' and ( key=10 or key=15 ) then
							-- 				tts_mode<=tts_play;
							-- 			end if;
							-- 		when tts_play=>
							-- 			tts_ena<='1';
							-- 			if key=10 then
							-- 				len<=5;
							-- 				if tts_play_count=1 then
							-- 					txt(0 to 4)<=tts_play_file & star;
							-- 				elsif tts_play_count=2 then
							-- 					txt(0 to 4)<=tts_play_file & tiger;
							-- 				elsif tts_play_count=3 then
							-- 					txt(0 to 4)<=tts_play_file & bee;
							-- 				end if;
							-- 			elsif key=15 then
							-- 				len<=2;
							-- 				if tts_func_count=3 then
							-- 					txt(0 to 1)<=tts_instant_pause;
							-- 					tts_count<=4;
							-- 				else
							-- 					txt(0 to 1)<=tts_instant_resume;
							-- 				end if;
							-- 			end if;
							-- 			if tts_done='1' then
							-- 				tts_ena<='0';
							-- 				tts_mode<=stop;
							-- 			end if;
							-- 		when stop=>
							-- 			if tts_busy = '0' then
							-- 				tts_mode<= idle;
							-- 				tts_count<=3;
							-- 			end if;
							-- 	end case;	

							-- when 4=>--skip File
							-- 	case tts_mode is
							-- 		when idle=>
							-- 			tts_mode<=tts_play;
							-- 		when tts_play=>
							-- 			tts_ena<='1';
							-- 			len<=2;
							-- 			txt(0 to 1)<=tts_instant_skip;
							-- 			if tts_done='1' then
							-- 				tts_ena<='0';
							-- 				tts_mode<=stop;
							-- 			end if;
							-- 		when stop=>
							-- 			if tts_busy = '0' then
							-- 				tts_mode<= idle;
							-- 				tts_count<=5;
							-- 			end if;
							-- 	end case;
							-- when 5=>--交單怠交
							-- 	case tts_mode is
							-- 		when idle=>
							-- 			tts_mode<=tts_play;
							-- 		when tts_play=>
							-- 			tts_ena<='1';
							-- 			len<=12;
							-- 			txt(0 to 11)<=tts_pause;
							-- 			if tts_done='1' then
							-- 				tts_ena<='0';
							-- 				tts_mode<=stop;
							-- 			end if;
							-- 		when stop=>
							-- 			if tts_busy = '0' then
							-- 				tts_mode<= idle;
							-- 				tts_count<=6;
							-- 			end if;
							-- 	end case;
							-- when 6=>--交單蝜潛交 back to 3
							-- 	case tts_mode is
							-- 		when idle=>
							-- 			if pressed='1' and key=15 then
							-- 				tts_mode<=tts_play;
							-- 			end if;
							-- 		when tts_play=>
							-- 			tts_ena<='1';
							-- 			if tts_func_count=2 then
							-- 				len<=12;
							-- 				txt(0 to 11)<=tts_continue;
							-- 			end if;
							-- 			if tts_done='1' then
							-- 				tts_ena<='0';
							-- 				tts_mode<=stop;
							-- 			end if;
							-- 		when stop=>
							-- 			if tts_busy = '0' then
							-- 				tts_mode<= tts_play;
							-- 				tts_count<=3;
							-- 			end if;
							-- 	end case;
						when others =>
					end case;
				when stop =>
					if done = '0' then
						load <= msec;
						time_ena <= '0';
						if tts_flag = '1' and font_busy = '0' then
							y <= 0;
							lcd_count <= lcd_count;
						end if;
					else
						if tts_flag = '1' and font_busy = '0' then
							lcd_count <= lcd_count + 1;
						end if;
						time_ena <= '1';
					end if;
			end case;
		end if;
	end process;
end architecture;

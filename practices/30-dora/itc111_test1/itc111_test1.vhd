--!pp on
--!def dht_h  l_paste_txt(l_addr, degreees, str_hums, (150, 65))
--!def degreees  l_paste_txt(l_addr, dht_t, "o", (145, 15))
--!def dht_t  l_paste_txt(l_addr, T, str_temp, (150, 2))

--!def T  l_paste_txt(l_addr, time_1s, timer_data, (130, 65))
--!def time_1s  l_paste_txt(l_addr, Vol_num," T         :", (130, 2))
--!def Vol_num l_paste_txt(l_addr, Vol, str_vol, (110, 67))
--!def Vol l_paste_txt(l_addr, File_3, " V o l .   :  ", (110, 2))
--!def File_3 l_paste_txt(l_addr, File_2, "           : T 3 . w a v ", (90, 2))
--!def File_2 l_paste_txt(l_addr, File_1, "           : T 2 . w a v ", (70, 2))
--!def File_1 l_paste_txt(l_addr, File_1_underline,  " F i l e 1 : T 1 . w a v ", (50, 2))
--!def File_1_underline l_paste_txt(l_addr, title,  underline, (file_y, 67))
--!def title l_paste_txt(l_addr, line_txt, "F 1 ,  N  ,  P ", (15, 28))
--!def line_txt l_paste_txt(l_addr, white, "___", (17, func_x))

--!def lcd_5 l_paste_txt(l_addr, lcd_4, ",  :  _  .", (100, 30))
--!def lcd_4 l_paste_txt(l_addr, lcd_3, "P  A  N  F  T", (80, 30))
--!def lcd_3 l_paste_txt(l_addr, lcd_2, "Vol.  On  Off", (60, 30))
--!def lcd_2 l_paste_txt(l_addr, lcd_1, "6  7  8  9  0", (40, 30))
--!def lcd_1 l_paste_txt(l_addr, white, "1  2  3  4  5", (20, 30))
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;
entity itc111_test1 is
	port (
		clk, rst_n : in std_logic;

		-- sw
		sw : in u8r_t;

		-- dht
		dht_data : inout std_logic;

		--seg
		seg_led, seg_com : out u8r_t;

		-- key
		key_row : in u4r_t;
		key_col : out u4r_t;

		-- tts
		tts_scl, tts_sda : inout std_logic;
		tts_mo           : in unsigned(2 downto 0);
		tts_rst_n        : out std_logic;

		-- lcd
		lcd_sclk, lcd_mosi, lcd_ss_n, lcd_dc, lcd_bl, lcd_rst_n : out std_logic
	);
end itc111_test1;

architecture arch of itc111_test1 is
	------------------------------------------------------------------signal
	--seg
	signal seg_data : string(1 to 8) := (others => ' ');
	signal dot : u8r_t := (others => '0');

	--key
	signal pressed, pressed_i : std_logic;
	signal key : i4_t;

	--dht11
	signal temp_int, hum_int : integer range 0 to 99;

	--f(1khz)
	signal msec, load : i32_t;
	signal time_ena : std_logic;
	--lcd
	signal wr_ena : std_logic;
	signal clk_main, l_addr_clk : std_logic;
	signal l_addr : l_addr_t;
	signal l_addr_scaled : l_addr_t;
	signal l_data_i : std_logic_vector(23 downto 0);
	signal l_data : l_px_t;
	signal func_x : integer range 0 to 127;
	signal file_y : integer range 0 to 159;

	--tts
	signal tts_ena : std_logic;
	signal tts_busy : std_logic;
	signal stop_speak : std_logic;
	signal stop_flag : std_logic;
	constant max_len : integer := 100;
	signal txt : u8_arr_t(0 to max_len - 1);
	signal len : integer range 0 to max_len;
	signal tts_done : std_logic;
	--clk_1hz
	signal clk_1hz, time_clk, clk_500mhz, clk_500ms : std_logic;
	--mode
	type mode_t is (idle, test_all, dht, tts, stop);
	signal mode : mode_t;

	--user
	signal mins : integer range 0 to 59 := 0;
	signal secs : integer range 0 to 59 := 50;
	signal done : std_logic;

	signal count : integer range 0 to 50;

	--01 dht
	signal seg_func_count : integer range 0 to 5;
	signal seg_count : integer range 0 to 9;
	--10 tts

	signal str_temp : string (1 to 5);
	signal str_hums : string (1 to 4);

	signal timer_data : string (1 to 7);
	type tts_mode_t is (idle, tts_play, stop);
	signal tts_mode : tts_mode_t;
	signal tts_count : integer range 0 to 10;
	signal tts_play_count : integer range 0 to 3;
	signal tts_func_count : integer range 1 to 3;
	signal volume : integer range 0 to 20;
	signal str_vol : string (1 to 2);
	signal underline : string (1 to 12) := "            ";
	constant star : u8_arr_t(0 to 3) := (x"03", x"e9", x"00", x"01");--1001.wav
	constant tiger : u8_arr_t(0 to 3) := (x"03", x"ea", x"00", x"01");--1002.wav
	constant bee : u8_arr_t(0 to 3) := (x"03", x"eb", x"00", x"01");--1003.wav
	--11 test_all
	--Tx.wav
	-- constant play_music1 : u8_arr_t(0 to 10) := (x"bc", x"bd", x"a9", x"f1", x"20", x"74", x"31", x"20", x"77", x"61", x"76");
	-- constant play_music2 : u8_arr_t(0 to 10) := (x"bc", x"bd", x"a9", x"f1", x"20", x"74", x"32", x"20", x"77", x"61", x"76");
	-- constant play_music3 : u8_arr_t(0 to 10) := (x"bc", x"bd", x"a9", x"f1", x"20", x"74", x"33", x"20", x"77", x"61", x"76");
	--Tx
	constant play_music1 : u8_arr_t(0 to 5) := (x"bc", x"bd", x"a9", x"f1", x"54", x"31");
	constant Play_music2 : u8_arr_t(0 to 5) := (x"bc", x"bd", x"a9", x"f1", x"54", x"32");
	constant Play_music3 : u8_arr_t(0 to 5) := (x"bc", x"bd", x"a9", x"f1", x"54", x"33");

	constant tts_pause : u8_arr_t(0 to 11) := (x"ad", x"b5", x"a4", x"eb", x"bc", x"c8", x"b0", x"b1", x"bc", x"b7", x"a9", x"f1");
	constant tts_continue : u8_arr_t(0 to 11) := (x"ad", x"b5", x"a4", x"eb", x"c4", x"7e", x"c4", x"f2", x"bc", x"b7", x"a9", x"f1");
	constant tts_setup : u8_arr_t(0 to 7) := (x"a5", x"5c", x"af", x"e0", x"b3", x"5d", x"a9", x"77");

begin

	----------------------------------------begin packages
	timer_inst : entity work.timer(arch)
		port map(
			clk   => clk,
			rst_n => rst_n,
			ena   => time_ena, --當ena='0', msec=load
			load  => load,     --起始值
			msec  => msec      --毫秒數
		);
	lcd_inst : entity work.lcd(arch)
		port map(
			clk        => clk,
			rst_n      => rst_n,
			lcd_sclk   => lcd_sclk,
			lcd_mosi   => lcd_mosi,
			lcd_ss_n   => lcd_ss_n,
			lcd_dc     => lcd_dc,
			lcd_bl     => lcd_bl,
			lcd_rst_n  => lcd_rst_n,
			brightness => 100,
			wr_ena     => wr_ena,
			addr       => l_addr,
			data       => l_data
		);

	clk1M_inst : entity work.clk(arch)
		generic map(
			freq => 1_000_000
		)
		port map(
			clk_in  => clk,
			rst_n   => rst_n,
			clk_out => clk_main
		);
	clk_inst : entity work.clk(arch)
		generic map(
			freq => 1
		)
		port map(
			clk_in  => clk,
			rst_n   => rst_n,
			clk_out => clk_1hz
		);
	dht_inst : entity work.dht(arch)
		port map(
			clk      => clk,
			rst_n    => rst_n,
			dht_data => dht_data,
			temp_int => temp_int,
			temp_dec => open,
			hum_int  => hum_int,
			hum_dec  => open
		);
	seg_inst : entity work.seg(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			seg_led => seg_led,  --腳位 a~g
			seg_com => seg_com,  --共同腳位
			data    => seg_data, --七段資料 輸入要顯示字元即可,遮末則輸入空白
			dot     => dot       --小數點 1 亮
			--輸入資料ex: b"01000000" = x"70"  
			--seg_deg 度C
		);

	key_inst : entity work.key(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			key_row => key_row,   --腳位
			key_col => key_col,   --腳位
			pressed => pressed_i, --pressed='1' 代表按住
			key     => key        --key=0 代表按下 key 1	key=1 代表按下 key 2...........
		);

	edge_lcd_clk : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => clk_main,
			rising  => l_addr_clk,
			falling => open
		);
	edge_inst_key : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => pressed_i,
			rising  => pressed,
			falling => open
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
	tts_inst : entity work.tts(arch)
		generic map(
			txt_len_max => max_len
		)
		port map(
			clk        => clk,
			rst_n      => rst_n,
			tts_scl    => tts_scl,
			tts_sda    => tts_sda,
			tts_mo     => tts_mo,
			tts_rst_n  => tts_rst_n,
			ena        => tts_ena,
			busy       => tts_busy,
			txt        => txt,
			txt_len    => len
		);
	---------------------------------------end packages
	process (clk, rst_n)
	begin
		if rst_n = '0' then
			count <= 0;
			mode <= idle;
			done <= '1';
			wr_ena <= '1';
			l_data <= white;
			seg_func_count <= 0;
			seg_data <= "        ";
			dot <= "00000000";
			load <= 0;
			time_ena <= '0';
			secs <= 50;
			mins <= 0;
			tts_count <= 0;
			tts_ena <= '0';
			tts_play_count <= 1;
			tts_func_count <= 1;
			stop_flag <= '0';
			volume <= 5;
			str_vol <= "05";
			tts_mode <= idle;
		elsif rising_edge(clk) then
			if l_addr_clk = '1' then
				if l_addr < l_addr'high then
					l_addr <= l_addr + 1;
				else
					l_addr <= 0;
				end if;
			end if;
			--change mode
			if (pressed = '1') and (key = 12) then
				case sw(6 to 7) is
					when "00" => ----idle
						seg_data <= "        ";
						dot <= "00000000";
						mode <= idle;
					when "01" => ----dht
						mode <= dht;
					when "10" => ----tts
						seg_data <= "        ";
						dot <= "00000000";
						mode <= tts;
					when "11" => ----test_all
						mode <= test_all;
				end case;
			end if;
			case mode is
				when idle =>
					time_ena <= '1';
					if pressed = '1' and key = 12 then
						if sw(6 to 7) = "00" then
							done <= not done;
						elsif sw(6 to 7) /= "00" then
							done <= '0';
						end if;
					end if;
					if msec <= 2 then
						l_data <= white;
					elsif msec <= 500 then
						l_data <= green;
					elsif msec <= 1000 then
						l_data <= red;
					elsif msec <= 1500 then
						l_data <= blue;
					elsif msec <= 2000 then
						l_data <= lcd_1;
					elsif msec <= 2500 then
						l_data <= lcd_2;
					elsif msec <= 3000 then
						l_data <= lcd_3;
					elsif msec <= 3500 then
						l_data <= lcd_4;
					elsif msec <= 4000 then
						l_data <= lcd_5;
					elsif msec <= 4500 then
						l_data <= lcd_6;
					else
						time_ena <= '0';
						load <= 0;
					end if;

					if done = '1' then
						load <= msec;
						time_ena <= '0';
						if msec <= 2 then
							l_data <= white;
						elsif msec <= 500 then
							l_data <= green;
						elsif msec <= 1000 then
							l_data <= red;
						elsif msec <= 1500 then
							l_data <= blue;
						elsif msec <= 2000 then
							l_data <= lcd_1;
						elsif msec <= 2500 then
							l_data <= lcd_2;
						elsif msec <= 3000 then
							l_data <= lcd_3;
						elsif msec <= 3500 then
							l_data <= lcd_4;
						elsif msec <= 4000 then
							l_data <= lcd_5;
						elsif msec <= 4500 then
							l_data <= lcd_6;
						end if;
					end if;
				when dht =>
					if pressed = '1' and key = 12 then
						if sw(6 to 7) = "01" then
							done <= not done;
						elsif sw(6 to 7) /= "01" then
							done <= '0';
						end if;
					end if;
					if done = '1' then
						l_data <= white;
						seg_data <= "        ";
						dot <= "00000000";
					else
						dot <= "00100000";
						if pressed = '1' then
							case key is
								when 9 =>
									if seg_func_count < 4 then
										seg_func_count <= seg_func_count + 1;
									else
										seg_func_count <= seg_func_count;
									end if;
								when 8 =>
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
							when others => null;
						end case;

					end if;
				when tts =>
					str_temp <= to_string(temp_int, temp_int'high, 10, 2) & "  C";
					str_hums <= to_string(hum_int, hum_int'high, 10, 2) & " %";
					if pressed = '1' and key = 12 then
						if sw(6 to 7) = "10" then
							done <= not done;
						elsif sw(6 to 7) /= "10" then
							done <= '0';
						end if;
					end if;
					if done = '0' then
						if tts_func_count = 1 then
							underline <= "            ";
						else
							underline <= "____________";
						end if;
						if pressed = '1' then--tts_play_count   tts_func_count   tts_play
							case key is
								when 9 => --up
									if tts_func_count = 1 then
										if volume < 20 then
											volume <= volume + 5;
										else
											volume <= 20;
										end if;
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
								when 8 => --down
									if tts_func_count = 1 then
										if volume > 0 then
											volume <= volume - 5;
										else
											volume <= 0;
										end if;
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
								when 15 => --chose function F1,N,p 
									if stop_speak = '1' then
										if tts_func_count >= 2 then
											tts_func_count <= 1;
										else
											tts_func_count <= tts_func_count + 1;
										end if;
									else
										if tts_func_count >= 3 then
											tts_func_count <= 2;
										else
											tts_func_count <= tts_func_count + 1;
										end if;
									end if;
								when others => null;
							end case;
						end if;
						case tts_mode is
							when idle =>
								if pressed = '1' and (key = 15 or key = 10 or key = 8 or key = 9) then
									tts_mode <= tts_play;
								end if;
							when tts_play =>
								tts_ena <= '1';
								if key = 10 and tts_func_count = 2 then
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
									if tts_func_count = 2 and stop_flag = '1' then
										tts_ena <= '1';
										txt(0 to 1) <= tts_instant_resume;
										stop_flag <= '0';
									elsif tts_func_count = 3 and stop_flag = '0' then
										tts_ena <= '1';
										txt(0 to 1) <= tts_instant_pause;
										stop_flag <= '1';
									end if;
								elsif key = 8 or key = 9 then
									if tts_func_count = 1 then
										str_vol <= to_string(volume, volume'high, 10, 2);
										len <= 2;
										if volume = 0 then
											txt(0 to 1) <= tts_set_vol & x"01";
										elsif volume = 5 then
											txt(0 to 1) <= tts_set_vol & x"c0";
										elsif volume = 10 then
											txt(0 to 1) <= tts_set_vol & x"d2";
										elsif volume = 15 then
											txt(0 to 1) <= tts_set_vol & x"e0";
										else
											txt(0 to 1) <= tts_set_vol & x"ff";
										end if;
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
						case tts_func_count is
							when 1 =>
								func_x <= 28;
							when 2 =>
								func_x <= 58;
							when 3 =>
								func_x <= 88;
						end case;
						case tts_play_count is
							when 1 =>
								file_y <= 52;
							when 2 =>
								file_y <= 72;
							when 3 =>
								file_y <= 92;
							when others => null;
						end case;
						timer_data <= to_string(mins, mins'high, 10, 2) & " : " & to_string(secs, secs'high, 10, 2);
						l_data <= l_map(dht_h, black, green);
						if tts_func_count = 2 and stop_speak = '0' then
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
							-- elsif stop_speak = '1' then
							-- 	mins <= 0;
							-- 	secs <= 50;
						end if;
					else
						l_data <= white;
					end if;
				when test_all =>
					if tts_func_count = 1 then----underline
						underline <= "            ";
						mins <= 0;
						secs <= 50;
					else
						underline <= "____________";
					end if;
					if pressed = '1' and key = 12 then--done
						if sw(6 to 7) = "11" then
							done <= not done;
						elsif sw(6 to 7) /= "11" then
							done <= '0';
						end if;
					end if;
					----------------------before
					-- if pressed = '1' then--tts_play_count   tts_func_count
					-- 	case key is
					-- 		when 9 => --up
					-- 			if volume < 20 then
					-- 				volume <= volume + 5;
					-- 			else
					-- 				volume <= 20;
					-- 			end if;
					-- 			if tts_func_count = 1 then
					-- 				tts_play_count <= 1;
					-- 			elsif tts_func_count = 2 then
					-- 				if tts_play_count > 1 then
					-- 					tts_play_count <= tts_play_count - 1;
					-- 				else
					-- 					tts_play_count <= tts_play_count;
					-- 				end if;
					-- 			else
					-- 				tts_play_count <= 0;
					-- 			end if;
					-- 		when 8 => --down
					-- 			if volume > 0 then
					-- 				volume <= volume - 5;
					-- 			else
					-- 				volume <= 0;
					-- 			end if;
					-- 			if tts_func_count = 1 then
					-- 				tts_play_count <= 1;
					-- 			elsif tts_func_count = 2 then
					-- 				if tts_play_count < 3 then
					-- 					tts_play_count <= tts_play_count + 1;
					-- 				else
					-- 					tts_play_count <= tts_play_count;
					-- 				end if;
					-- 			else
					-- 				tts_play_count <= 0;
					-- 			end if;
					-- 		when 15 => --chose function F1,N,p 
					-- 			if stop_speak = '1' then
					-- 				if tts_func_count >= 2 then
					-- 					tts_func_count <= 1;
					-- 				else
					-- 					tts_func_count <= tts_func_count + 1;
					-- 				end if;
					-- 			else
					-- 				if tts_func_count >= 3 then
					-- 					tts_func_count <= 2;
					-- 				else
					-- 					tts_func_count <= tts_func_count + 1;
					-- 				end if;
					-- 			end if;
					-- 		when 14 => --show seg data
					-- 			dot <= "00100000";
					-- 			seg_data <= "F1  " & to_string(temp_int, temp_int'high, 10, 2) & seg_deg & 'C';
					-- 		when others => null;
					-- 	end case;
					-- end if;
					-- case tts_count is --tts_play
					-- 	when 0 => --撥放功能設定
					-- 		case tts_mode is
					-- 			when idle =>
					-- 				if pressed = '1' and key = 15 then
					-- 					tts_mode <= tts_play;
					-- 				end if;
					-- 			when tts_play =>
					-- 				tts_ena <= '1';
					-- 				if tts_func_count = 2 then
					-- 					len <= 8;
					-- 					txt(0 to 7) <= tts_setup;
					-- 				end if;
					-- 				if tts_done = '1' then
					-- 					tts_ena <= '0';
					-- 					tts_mode <= stop;
					-- 				end if;
					-- 			when stop =>
					-- 				if tts_busy = '0' then
					-- 					tts_count <= 1;
					-- 					tts_mode <= idle;
					-- 				end if;
					-- 		end case;
					-- 	when 1 => --撥放T1
					-- 		case tts_mode is
					-- 			when idle =>
					-- 				if pressed = '1' and (key = 15 or key = 10 or key = 8 or key = 9) then
					-- 					tts_mode <= tts_play;
					-- 				end if;
					-- 			when tts_play =>
					-- 				tts_ena <= '1';
					-- 				len <= 6;
					-- 				if key = 10 then
					-- 					if tts_play_count = 1 then
					-- 						txt(0 to 5) <= play_music1;
					-- 					elsif tts_play_count = 2 then
					-- 						txt(0 to 5) <= play_music2;
					-- 					elsif tts_play_count = 3 then
					-- 						txt(0 to 5) <= Play_music3;
					-- 					end if;
					-- 				elsif key = 15 then
					-- 					len <= 2;
					-- 					if tts_func_count = 2 then
					-- 						txt(0 to 1) <= tts_instant_resume;
					-- 					else
					-- 						txt(0 to 1) <= tts_instant_pause;
					-- 					end if;
					-- 				elsif key = 8 or key = 9 then
					-- 					if tts_func_count = 1 then
					-- 						str_vol <= to_string(volume, volume'high, 10, 2);
					-- 						if volume = 0 then
					-- 							txt(0 to 1) <= tts_set_vol & x"01";
					-- 						elsif volume = 5 then
					-- 							txt(0 to 1) <= tts_set_vol & x"c0";
					-- 						elsif volume = 10 then
					-- 							txt(0 to 1) <= tts_set_vol & x"d2";
					-- 						elsif volume = 15 then
					-- 							txt(0 to 1) <= tts_set_vol & x"e0";
					-- 						else
					-- 							txt(0 to 1) <= tts_set_vol & x"ff";
					-- 						end if;
					-- 					end if;
					-- 				end if;
					-- 				if tts_done = '1' then
					-- 					tts_ena <= '0';
					-- 					tts_mode <= stop;
					-- 				end if;
					-- 			when stop =>
					-- 				if tts_busy = '0' then
					-- 					tts_count <= 2;
					-- 					tts_mode <= tts_play;
					-- 				end if;
					-- 		end case;
					-- 	when 2 => --Play File
					-- 		case tts_mode is
					-- 			when idle =>
					-- 				if pressed = '1' and (key = 15 or key = 10) then
					-- 					tts_mode <= tts_play;
					-- 				end if;
					-- 			when tts_play =>
					-- 				tts_ena <= '1';
					-- 				if key = 10 then
					-- 					if tts_play_count = 1 then
					-- 						len <= 5;
					-- 						txt(0 to 4) <= tts_play_file & star;
					-- 					elsif tts_play_count = 2 then
					-- 						len <= 5;
					-- 						txt(0 to 4) <= tts_play_file & tiger;
					-- 					elsif tts_play_count = 3 then
					-- 						len <= 5;
					-- 						txt(0 to 4) <= tts_play_file & bee;
					-- 					end if;
					-- 					if tts_done = '1' then
					-- 						tts_ena <= '0';
					-- 						tts_mode <= stop;
					-- 					end if;
					-- 					-- elsif key=15 then
					-- 					-- 	len<=2;
					-- 					-- 	if tts_func_count=2 then
					-- 					-- 		txt(0 to 1)<=tts_instant_resume;
					-- 					-- 	else
					-- 					-- 		txt(0 to 1)<=tts_instant_pause;
					-- 					-- 	end if;
					-- 				end if;
					-- 				if tts_done = '1' then
					-- 					tts_ena <= '0';
					-- 					tts_mode <= stop;
					-- 				end if;
					-- 			when stop =>
					-- 				if tts_busy = '0' then
					-- 					tts_mode <= idle;
					-- 					tts_count <= 1;
					-- 				end if;
					-- 		end case;
					-- 	when others =>
					-- end case;
					-- case tts_func_count is--x
					-- 	when 1 =>
					-- 		func_x <= 28;
					-- 	when 2 =>
					-- 		func_x <= 58;
					-- 	when 3 =>
					-- 		func_x <= 88;
					-- end case;
					-- case tts_play_count is--y
					-- 	when 1 =>
					-- 		file_y <= 52;
					-- 	when 2 =>
					-- 		file_y <= 72;
					-- 	when 3 =>
					-- 		file_y <= 92;
					-- 	when others => null;
					-- end case;
					-- if tts_func_count = 2 and stop_speak = '0' and tts_count = 1 then
					-- 	if time_clk = '1' then
					-- 		if secs = secs'high then
					-- 			secs <= 0;
					-- 			if mins = mins'high then
					-- 				mins <= 0;
					-- 			else
					-- 				mins <= mins + 1;
					-- 			end if;
					-- 		else
					-- 			secs <= secs + 1;
					-- 		end if;
					-- 	end if;
					-- end if;
					-- timer_data <= to_string(mins, mins'high, 10, 2) & " : " & to_string(secs, secs'high, 10, 2);
					-- l_data <= l_map(T, black, green);
					if pressed = '1' and key = 14 then--seg_data
						dot <= "00100000";
						seg_data <= "F1  " & to_string(temp_int, temp_int'high, 10, 2) & seg_deg & 'C';
					end if;
					case count is
						when 0 => --撥放功能設定
							case tts_mode is
								when idle =>
									if pressed = '1' and key = 15 then
										tts_mode <= tts_play;
									end if;
								when tts_play =>
									tts_ena <= '1';
									len <= 8;
									txt(0 to 7) <= tts_setup;
									if tts_done = '1' then
										tts_ena <= '0';
										tts_mode <= stop;
									end if;
								when stop =>
									count <= 1;
									if tts_busy = '0' then
										tts_mode <= idle;
									end if;
							end case;
						when 1 => --play file
							if pressed = '1' then--tts_play_count   tts_func_count
								case key is
									when 9 => --up
										if tts_func_count = 1 then
											if volume < 20 then
												volume <= volume + 5;
											else
												volume <= 20;
											end if;
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
									when 8 => --down
										if tts_func_count = 1 then
											if volume > 0 then
												volume <= volume - 5;
											else
												volume <= 0;
											end if;
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
									when 15 => --chose function F1,N,p 
										if stop_speak = '1' then
											if tts_func_count >= 2 then
												tts_func_count <= 1;
											else
												tts_func_count <= tts_func_count + 1;
											end if;
										else
											if tts_func_count >= 3 then
												tts_func_count <= 2;
											else
												tts_func_count <= tts_func_count + 1;
											end if;
										end if;
									when others => null;
								end case;
							end if;
							case tts_count is --tts_play
								when 0 => --撥放T1
									case tts_mode is
										when idle =>
											if pressed = '1' and (key = 15 or key = 10 or key = 8 or key = 9 or key = 11) then
												tts_mode <= tts_play;
											end if;
										when tts_play =>
											if key = 10 and tts_func_count = 2 then--播放Tx
												tts_ena <= '1';
												len <= 6;
												if tts_play_count = 1 then
													txt(0 to 5) <= play_music1;
												elsif tts_play_count = 2 then
													txt(0 to 5) <= play_music2;
												elsif tts_play_count = 3 then
													txt(0 to 5) <= Play_music3;
												end if;
											elsif key = 15 then--pause/resume
												len <= 2;
												if tts_func_count = 2 and stop_flag = '1' then
													tts_ena <= '1';
													txt(0 to 1) <= tts_instant_resume;
													stop_flag <= '0';
												elsif tts_func_count = 3 and stop_flag = '0' then
													tts_ena <= '1';
													txt(0 to 1) <= tts_instant_pause;
													stop_flag <= '1';
												end if;
											elsif key = 8 or key = 9 then--vol adjust
												if tts_func_count = 1 then
													tts_ena <= '1';
													len <= 2;
													str_vol <= to_string(volume, volume'high, 10, 2);
													if volume = 0 then
														txt(0 to 1) <= tts_set_vol & x"01";
													elsif volume = 5 then
														txt(0 to 1) <= tts_set_vol & x"c0";
													elsif volume = 10 then
														txt(0 to 1) <= tts_set_vol & x"d2";
													elsif volume = 15 then
														txt(0 to 1) <= tts_set_vol & x"e0";
													else
														txt(0 to 1) <= tts_set_vol & x"ff";
													end if;
												end if;
											elsif key = 11 and tts_func_count = 2 then
												tts_ena <= '1';
												len <= 2;
												txt(0 to 1) <= tts_instant_skip;
											end if;
											if tts_done = '1' then
												tts_ena <= '0';
												tts_mode <= stop;
											end if;
										when stop =>
											if tts_busy = '0' then
												if key = 10 then
													tts_count <= 1;
													tts_mode <= tts_play;
												end if;
												tts_mode <= idle;
											end if;
									end case;
								when 1 => --Play File
									case tts_mode is
										when idle =>
											if (pressed = '1' and (key = 15 or key = 10 or key = 8 or key = 9)) then
												tts_mode <= tts_play;
											end if;
										when tts_play =>
											tts_ena <= '1';
											len <= 5;
											if tts_play_count = 1 then
												txt(0 to 4) <= tts_play_file & star;
											elsif tts_play_count = 2 then
												txt(0 to 4) <= tts_play_file & tiger;
											elsif tts_play_count = 3 then
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
										when stop =>
											if tts_busy = '0' then
												tts_mode <= idle;
												tts_count <= 0;
											end if;
									end case;
								when others =>
							end case;
							case tts_func_count is--x
								when 1 =>
									func_x <= 28;
								when 2 =>
									func_x <= 58;
								when 3 =>
									func_x <= 88;
							end case;
							case tts_play_count is--y
								when 1 =>
									file_y <= 52;
								when 2 =>
									file_y <= 72;
								when 3 =>
									file_y <= 92;
								when others => null;
							end case;
							if tts_func_count = 2 and stop_speak = '0' and tts_count = 0 then
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
							timer_data <= to_string(mins, mins'high, 10, 2) & " : " & to_string(secs, secs'high, 10, 2);
							l_data <= l_map(T, black, green);
						when others => null;
					end case;
				when stop =>
			end case;
		end if;
	end process;
end architecture;

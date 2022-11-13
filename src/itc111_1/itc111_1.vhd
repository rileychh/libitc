library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;
entity itc111_1 is
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
		dbg_b            : out u8r_t;
		tts_rst_n        : out std_logic;

		-- lcd
		lcd_sclk, lcd_mosi, lcd_ss_n, lcd_dc, lcd_bl, lcd_rst_n : out std_logic
	);
end itc111_1;

architecture arch of itc111_1 is

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

	--lcd_draw
	signal bg_color, text_color : l_px_t;
	signal addr : l_addr_t;
	signal text_size : integer range 1 to 12;
	signal data : string(1 to 12);
	signal font_start, font_busy, lcd_clear : std_logic;
	signal draw_done, draw_start : std_logic;
	signal x : integer range -5 to 159;
	signal y : integer range 0 to 159;

	--tts
	signal tts_ena : std_logic;
	signal tts_busy : std_logic;
	constant max_len : integer := 100;
	signal txt : u8_arr_t(0 to max_len - 1);
	signal len : integer range 0 to max_len;
	signal tts_done : std_logic;
	--clk_1hz
	signal clk_1hz, time_clk : std_logic;
	--mode
	type mode_t is (idle, buff, auto, dht, tts, stop);
	signal mode : mode_t;

	--user
	signal mins : integer range 0 to 59 := 0;
	signal secs : integer range 0 to 59 := 50;
	signal done : std_logic;

	signal lcd_count : integer range 0 to 10;

	--01 dht
	signal seg_func_count : integer range 0 to 4;

	--10 tts
	type tts_mode_t is (idle, tts_play, stop);
	signal tts_mode : tts_mode_t;
	signal addr_ena : std_logic := '0';
	signal tts_flag : std_logic := '0';
	signal stop_flag : std_logic := '0';
	signal tts_count : integer range 0 to 10;
	signal tts_play_count : integer range 0 to 3;
	signal tts_func_count : integer range 1 to 3;
	signal play_count : integer range 0 to 3;
	signal func_count : integer range 1 to 3;
	-------------big5 code
	-- constant star : u8_arr_t(0 to 29) :=(
	--         x"a4", x"40", x"b0", x"7b", x"a4", x"40", x"b0", x"7b", x"ab", x"47", x"b4", x"b9", x"b4", x"b9", x"a1", x"40",
	--         x"ba", x"a1", x"a4", x"d1", x"b3", x"a3", x"ac", x"4f", x"a4", x"70", x"ac", x"50", x"ac", x"50"
	-- );
	-- constant bee : u8_arr_t(0 to 51) := (
	--         x"b6", x"e4", x"b6", x"e4", x"b6", x"e4", x"a1", x"41", x"b6", x"e4", x"b6", x"e4", x"b6", x"e4", x"a4", x"6a",
	--         x"ae", x"61", x"a4", x"40", x"b0", x"5f", x"b6", x"d4", x"b0", x"b5", x"a4", x"75", x"a8", x"d3", x"a5", x"5e",
	--         x"a5", x"5e", x"a1", x"41", x"a5", x"68", x"a5", x"5e", x"a5", x"5e", x"b0", x"b5", x"a4", x"75", x"bf", x"b3",
	--         x"a8", x"fd", x"bf", x"40"
	-- );
	-- constant tiger : u8_arr_t(0 to 27) := (
	--         x"a8", x"e2", x"b0", x"a6", x"a6", x"d1", x"aa", x"ea", x"a8", x"e2", x"b0", x"a6", x"a6", x"d1", x"aa", x"ea",
	--         x"b6", x"5d", x"b1", x"6f", x"a7", x"d6", x"b6", x"5d", x"b1", x"6f", x"a7", x"d6"
	-- );
	--------------
	constant star : u8_arr_t(0 to 3) := (x"03", x"e9", x"00", x"01");--1001.wav
	constant tiger : u8_arr_t(0 to 3) := (x"03", x"ea", x"00", x"02");--1002.wav
	constant bee : u8_arr_t(0 to 3) := (x"03", x"eb", x"00", x"02");--1003.wav
	--11 auto
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
	------------------------------------------------------------------end signal

begin

	----------------------------------------begin packages
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

	timer_inst : entity work.timer(arch)
		port map(
			clk   => clk,
			rst_n => rst_n,
			ena   => time_ena, --當ena='0', msec=load
			load  => load,     --起始值
			msec  => msec      --毫秒數
		);

	edge_inst_key : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => pressed_i,
			rising  => pressed,
			falling => open
		);

	edge_inst_font_done : entity work.edge(arch)
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
	tts_inst : entity work.tts_stop(arch)
		generic map(
			txt_len_max => max_len
		)
		port map(
			clk       => clk,
			rst_n     => rst_n,
			tts_scl   => tts_scl,
			tts_sda   => tts_sda,
			tts_mo    => tts_mo,
			tts_rst_n => tts_rst_n,
			ena       => tts_ena,
			busy      => tts_busy,
			txt       => txt,
			txt_len   => len
		);
	---------------------------------------end packages
	process (clk, rst_n)
	begin
		if rst_n = '0' then
			bg_color <= white;
			done <= '0';
			lcd_count <= 1;
			lcd_clear <= '1';
			font_start <= '0';
			seg_func_count <= 0;
			seg_data <= "        ";
			dot <= "00000000";
			data <= "            ";
			load <= 0;
			time_ena <= '0';
			x <= 0;
			y <= 0;
			secs <= 50;
			mins <= 0;
			tts_count <= 0;
			tts_ena <= '0';
			tts_play_count <= 1;
			tts_func_count <= 1;
			play_count <= 0;
			func_count <= 1;
			tts_mode <= idle;
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
						when 0 => --撥放功能設定
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
						when 1 => --撥放T1
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
							-- when 5=>--撥放音樂暫停撥放
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
							-- when 6=>--撥放音樂繼續撥放 back to 3
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

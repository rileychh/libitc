library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_unsigned.all;

use work.itc.all;
use work.itc_lcd.all;

entity test_111_1 is
	port (
		-- system
		clk, rst_n : in std_logic;
		-- lcd
		lcd_sclk, lcd_mosi, lcd_ss_n, lcd_dc, lcd_bl, lcd_rst_n : out std_logic;
		-- sw
		sw : in u8r_t;
		-- key
		key_row : in u4r_t;
		key_col : out u4r_t;
		-- dht11
		dht_data : inout std_logic;
		-- seg
		seg_led, seg_com : out u8r_t;
		-- tts
		tts_scl, tts_sda : inout std_logic;
		tts_mo           : in unsigned(2 downto 0);
		tts_rst_n        : out std_logic
	);
end test_111_1;

architecture arch of test_111_1 is
	signal inter_rst : std_logic;
	signal clk1, clk_1hz : std_logic;
	signal clk10000, clk_10000 : std_logic;
	signal mod11 : std_logic;
	signal pause : std_logic;
	signal s1_p : std_logic;

	type mode is (lcd_res, dht_seg, tts_t, stop, lcd_stop);
	signal mode_t : mode;
	-- LCD
	signal bg_color : l_px_t;
	signal addr : l_addr_t;
	signal x : integer range -5 to 159;
	signal y : integer range 0 to 159;
	signal text_size : integer range 1 to 12;
	signal data : string(1 to 12);
	signal font_start, font_busy, lcd_clear : std_logic;
	signal draw_done, draw_start : std_logic;
	signal lcd_count, lcd_mem : integer range 0 to 9;
	signal color : l_px_arr_t(1 to 12);
	signal lcd_mod_count : integer range 0 to 7;
	signal lcd_flash : std_logic;
	signal vol : integer range 0 to 99;
	signal music_sec, music_min : integer range 0 to 59;
	constant all_green : l_px_arr_t(1 to 12) := (green, green, green, green, green, green, green, green, green, green, green, green);
	constant all_red : l_px_arr_t(1 to 12) := (red, red, red, red, red, red, red, red, red, red, red, red);
	constant all_blue : l_px_arr_t(1 to 12) := (blue, blue, blue, blue, blue, blue, blue, blue, blue, blue, blue, blue);
	constant F1_0 : l_px_arr_t(1 to 12) := (white, white, white, green, green, green, green, green, green, green, green, green);
	constant F1_1 : l_px_arr_t(1 to 12) := (blue, blue, blue, green, green, green, green, green, green, green, green, green);
	constant F2_red : l_px_arr_t(1 to 12) := (red, red, red, green, green, green, green, green, green, green, green, green);
	constant N_0 : l_px_arr_t(1 to 12) := (green, green, green, green, green, green, white, green, green, green, green, green);
	constant N_red : l_px_arr_t(1 to 12) := (green, green, green, green, green, green, red, green, green, green, green, green);
	constant P_0 : l_px_arr_t(1 to 12) := (green, green, green, green, green, green, green, green, green, green, white, green);
	constant P_red : l_px_arr_t(1 to 12) := (green, green, green, green, green, green, green, green, green, green, red, green);
	constant P1_blue : l_px_arr_t(1 to 12) := (green, green, green, green, green, green, blue, blue, blue, blue, blue, blue);
	constant file_blue : l_px_arr_t(1 to 12) := (red, red, red, red, red, red, blue, blue, blue, blue, blue, blue);

	-- timer
	signal msec, load, msec2 : i32_t;
	signal time_ena, time_ena2 : std_logic;
	-- key
	signal pressed_i, pressed : std_logic;
	signal key_data : i4_t;
	signal key_mem : std_logic;
	signal s5_mem : integer range 0 to 2;
	signal s4_mem : std_logic;
	-- dht11
	signal temp_int, hum_int : integer range 0 to 99;
	signal temp_dec, hum_dec : integer range 0 to 9;
	-- seg
	signal seg_data : string(1 to 8);
	signal seg_dot : u8r_t;
	signal seg_mod : std_logic_vector(0 to 1);
	signal seg_flash : std_logic;
	-- tts
	constant max_len : integer := 50;
	constant music1 : u8_arr_t(0 to 4) := (tts_play_file, x"03", x"e9", x"00", x"01");
	constant music2 : u8_arr_t(0 to 4) := (tts_play_file, x"03", x"ea", x"00", x"01");
	constant music3 : u8_arr_t(0 to 4) := (tts_play_file, x"07", x"d1", x"00", x"01");
	constant tts1_1 : u8_arr_t(0 to 19) := (x"a8", x"74", x"b2", x"ce", x"b6", x"7d", x"be", x"f7", x"a1", x"41", x"a4", x"b5", x"a4", x"d1", x"b7", x"c5", x"ab", x"d7", x"ac", x"b0");
	constant tts1_2 : u8_arr_t(0 to 1) := (x"ab", x"d7");
	constant tts2 : u8_arr_t(0 to 21) := (x"b1", x"fd", x"a5", x"48", x"ad", x"b5", x"b6", x"71", x"ac", x"b0", x"30", x"36", x"bc", x"bd", x"a9", x"f1", x"50", x"32", x"2e", x"77", x"61", x"76");
	constant tts3 : u8_arr_t(0 to 11) := (x"b6", x"7d", x"b1", x"d2", x"b0", x"b1", x"a4", x"ee", x"a5", x"5c", x"af", x"e0");
	constant tts4 : u8_arr_t(0 to 11) := (x"c3", x"f6", x"b3", x"ac", x"b0", x"b1", x"a4", x"ee", x"a5", x"5c", x"af", x"e0");
	signal tts_ena : std_logic;
	signal tts_busy : std_logic;
	signal tts_data : u8_arr_t(0 to max_len - 1);
	signal tts_len : integer range 0 to max_len;
	signal tts_count : integer;
	signal tts_done : std_logic;
begin
	edge_inst_tts_busy : entity work.edge(arch)
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
			clk       => clk,
			rst_n     => rst_n,
			tts_scl   => tts_scl,
			tts_sda   => tts_sda,
			tts_mo    => tts_mo,
			tts_rst_n => tts_rst_n,
			ena       => tts_ena,
			busy      => tts_busy,
			txt       => tts_data,
			txt_len   => tts_len
		);
	clk_inst10000 : entity work.clk(arch)
		generic map(
			freq => 10000
		)
		port map(
			clk_in  => clk,
			rst_n   => rst_n,
			clk_out => clk10000
		);
	edge_inst10000 : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => clk10000,
			rising  => clk_10000,
			falling => open
		);
	clk_inst : entity work.clk(arch)
		generic map(
			freq => 1
		)
		port map(
			clk_in  => clk,
			rst_n   => rst_n,
			clk_out => clk1
		);
	edge_inst : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => clk1,
			rising  => clk_1hz,
			falling => open
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
	dht_inst : entity work.dht(arch)
		port map(
			clk      => clk,
			rst_n    => rst_n,
			dht_data => dht_data,
			temp_int => temp_int,
			hum_int  => hum_int,
			temp_dec => temp_dec,
			hum_dec  => hum_dec
		);
	edge_key_inst : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => pressed_i,
			rising  => pressed,
			falling => open
		);
	key_inst : entity work.key(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			key_row => key_row,
			key_col => key_col,
			pressed => pressed_i,
			key     => key_data
		);
	timer_inst : entity work.timer(arch)
		port map(
			clk   => clk,
			rst_n => rst_n,
			ena   => time_ena,
			load  => load,
			msec  => msec
		);
	timer_inst2 : entity work.timer(arch)
		port map(
			clk   => clk,
			rst_n => rst_n,
			ena   => time_ena2,
			load  => 0,
			msec  => msec2
		);
	edge_inst_lcd_done : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => font_busy,
			rising  => draw_start,
			falling => draw_done
		);
	lcd_draw : entity work.gen_font(arch)
		port map(
			clk              => clk,
			rst_n            => rst_n,
			x                => x,
			y                => y,
			font_start       => font_start,
			font_busy        => font_busy,
			text_size        => text_size,
			data             => data,
			text_color       => black,
			addr             => addr,
			bg_color         => bg_color,
			clear            => lcd_clear,
			lcd_sclk         => lcd_sclk,
			lcd_mosi         => lcd_mosi,
			lcd_ss_n         => lcd_ss_n,
			lcd_dc           => lcd_dc,
			lcd_bl           => lcd_bl,
			lcd_rst_n        => lcd_rst_n,
			text_color_array => color

		);
	inter_rst <= '0' when (key_data = 1) and (pressed = '1') else '1';
	process (clk, rst_n, inter_rst)
	begin
		if rst_n = '0' or inter_rst = '0' then
			s1_p <= '1';
			seg_dot <= "00000000";
			bg_color <= white;
			lcd_clear <= '1';
			lcd_count <= 0;
			mode_t <= stop;
		elsif rising_edge(clk) then
			if pressed = '1' and key_data = 0 then
				case sw(6 to 7) is
					when "00" =>
						s1_p <= not s1_p;
						mod11 <= '0';
						-- mode_t <= lcd_res;
						if s1_p = '0' then
							lcd_mem <= lcd_count;
							mode_t <= lcd_stop;
						else
							lcd_count <= lcd_mem;
							mode_t <= lcd_res;
						end if;
					when "01" =>
						lcd_count <= 0;
						mod11 <= '0';
						lcd_clear <= '1';
						bg_color <= white;
						seg_mod <= "00";
						key_mem <= '0';
						mode_t <= dht_seg;
					when "10" =>
						seg_data <= "        ";
						mod11 <= '0';
						s5_mem <= 0;
						music_sec <= 0;
						music_min <= 0;
						vol <= 0;
						lcd_mod_count <= 0;
						x <= 0;
						lcd_count <= 0;
						font_start <= '0';
						lcd_clear <= '1';
						bg_color <= white;
						mode_t <= tts_t;
					when "11" =>
						tts_ena <= '0';
						mod11 <= '1';
						s5_mem <= 0;
						music_sec <= 0;
						music_min <= 0;
						vol <= 0;
						lcd_mod_count <= 0;
						x <= 0;
						lcd_count <= 0;
						font_start <= '0';
						lcd_clear <= '1';
						bg_color <= white;
						mode_t <= tts_t;
				end case;
			end if;
			case mode_t is
				when lcd_res =>
					seg_data <= "        ";
					case lcd_count is
						when 0 => -- green
							lcd_clear <= '1';
							bg_color <= green;
							seg_data <= "       0";
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
								if y >= y'high and msec >= 1000 then
									lcd_clear <= '1';
									lcd_count <= 1;
								end if;
							end if;
						when 1 => -- red
							seg_data <= "       1";
							lcd_clear <= '1';
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
								if y >= y'high and msec >= 2000 then
									lcd_clear <= '1';
									lcd_count <= 2;
								end if;
							end if;
						when 2 => -- blue
							seg_data <= "       2";
							lcd_clear <= '1';
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
								time_ena <= '1';
								y <= 0;
								if y >= y'high and msec >= 3000 then
									lcd_clear <= '1';
									lcd_count <= 3;
								end if;
							end if;
						when 3 => -- white
							seg_data <= "       3";
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
								time_ena <= '1';
								lcd_clear <= '1';
								y <= 10;
								color <= all_green;
								lcd_count <= 4;
							end if;
						when 4 => --1~5
							seg_data <= "       4";
							time_ena <= '1';
							if msec < 3500 then
								lcd_clear <= '0';
								y <= 10;
							else
								data <= " 1 2 3 4 5  ";
								font_start <= '1';
								if font_busy = '0' and msec >= 4000 then
									color <= all_red;
									font_start <= '0';
									y <= 30;
									lcd_count <= 5;
								end if;
							end if;
						when 5 => --6~0
							seg_data <= "       5";
							time_ena <= '1';
							if y = 30 then
								data <= " 6 7 8 9 0  ";
								font_start <= '1';
							end if;
							if font_busy = '0' and msec >= 4500 then
								color <= all_blue;
								font_start <= '0';
								y <= 50;
								lcd_count <= 6;
							end if;
						when 6 => --Vol. On 
							seg_data <= "       6";
							time_ena <= '1';
							if y = 50 then
								data <= " Vol.On     ";
								font_start <= '1';
							end if;
							if font_busy = '0' and msec >= 5000 then
								font_start <= '0';
								y <= 50;
								lcd_count <= 7;
							end if;
						when 7 => --Vol. On off 
							seg_data <= "       7";
							time_ena <= '1';
							if y = 50 then
								data <= " Vol.On off ";
								font_start <= '1';
							end if;
							if font_busy = '0' and msec >= 5500 then
								color <= all_red;
								font_start <= '0';
								y <= 70;
								lcd_count <= 8;
							end if;
						when 8 => --P A N F T
							seg_data <= "       8";
							time_ena <= '1';
							if y = 70 then
								data <= " P A N F T  ";
								font_start <= '1';
							end if;
							if font_busy = '0' and msec >= 6000 then
								color <= all_green;
								font_start <= '0';
								y <= 90;
								lcd_count <= 9;
							end if;
						when 9 => --, : _ .
							seg_data <= "       9";
							if y = 90 then
								data <= " . _ : ,    ";
								font_start <= '1';
								time_ena <= '1';
							end if;
							if font_busy = '0' and msec >= 6500 then
								lcd_clear <= '1';
								font_start <= '0';
								lcd_count <= 0;
								load <= 0;
								time_ena <= '0';
							end if;
						when others => null;
					end case;

				when dht_seg =>
					lcd_clear <= '1';
					bg_color <= white;
					if pressed = '1' and key_data = 2 then
						seg_mod <= "01";
					elsif seg_mod >= "01" and pressed = '1' and key_data = 4 then
						if key_mem = '1' then
							seg_flash <= not seg_flash;
							key_mem <= '0';
						else
							if seg_mod /= "11" then
								seg_mod <= seg_mod + 1;
							else
								seg_mod <= seg_mod;
							end if;
						end if;
					elsif seg_mod = "11" and pressed = '1' and key_data = 6 then
						key_mem <= '1';
					elsif key_mem = '1' and pressed = '1' and key_data = 4 then
						seg_flash <= not seg_flash;
						key_mem <= '0';
					end if;
					case seg_mod is
						when "00" => seg_data <= "F0.-----";
						when "01" =>
							if seg_flash = '1' then
								time_ena <= '1';
								if msec <= 500 then
									seg_data <= "F1.     ";
								elsif msec <= 1000 then
									seg_data <= "F1." & to_string(hum_int, hum_int'high, 10, 2) & NUL & "/o";
								elsif msec > 1000 then
									time_ena <= '0';
								end if;
							else
								seg_data <= "F1." & to_string(hum_int, hum_int'high, 10, 2) & NUL & "/o";
							end if;
						when "10" =>
							if seg_flash = '1' then
								time_ena <= '1';
								if msec <= 500 then
									seg_data <= "F2.     ";
								elsif msec <= 1000 then
									seg_data <= "F2. " & to_string(temp_int, temp_int'high, 10, 2) & NUL & 'C';
								elsif msec > 1000 then
									time_ena <= '0';
								end if;
							else
								seg_data <= "F2. " & to_string(temp_int, temp_int'high, 10, 2) & NUL & 'C';
							end if;
						when "11" =>
							if seg_flash = '0' then
								seg_data <= "F3.FL:OF";
							else
								seg_data <= "F3.FL:ON";
							end if;
						when others => null;
					end case;
				when tts_t =>
					if mod11 = '1' then
						if seg_flash = '1' then
							time_ena2 <= '1';
							if msec2 <= 500 then
								seg_data <= "F2.     ";
							elsif msec2 <= 1000 then
								seg_data <= "F2. " & to_string(temp_int, temp_int'high, 10, 2) & NUL & 'C';
							elsif msec2 > 1000 then
								time_ena2 <= '0';
							end if;
						else
							seg_data <= "F2. " & to_string(temp_int, temp_int'high, 10, 2) & NUL & 'C';
						end if;
					else
						seg_data <= "        ";
					end if;
					if lcd_mod_count = 0 then
						if mod11 = '1' then
							tts_ena <= '1';
							tts_data(0 to 27) <= tts1_1 & to_big(temp_int) & tts1_2;
							tts_len <= 28;
						end if;
						time_ena <= '1';
						s4_mem <= '0';
						s5_mem <= 0;
						music_sec <= 0;
						music_min <= 0;
						vol <= 0;
						if pressed = '1' and key_data = 6 then
							tts_ena <= '0';
							lcd_mod_count <= 1;
						end if;
						if msec < 500 then
							lcd_flash <= '0';
						elsif msec < 1000 then
							lcd_flash <= '1';
						elsif msec >= 1000 then
							time_ena <= '0';
						end if;
					elsif lcd_mod_count = 1 then
						if mod11 = '1' then
							tts_ena <= '1';
							tts_data(0 to 21) <= tts2;
							tts_len <= 22;
							if tts_busy = '1' then
								tts_ena <= '0';
							end if;
						end if;
						time_ena <= '0';
						if pressed = '1' and key_data = 2 then
							lcd_mod_count <= 2;
						end if;
					elsif lcd_mod_count = 2 then
						if mod11 = '1' then
							tts_ena <= '1';
							tts_data(0 to 21) <= tts2;
							tts_len <= 22;
							if tts_busy = '1' then
								tts_ena <= '0';
							end if;
						end if;
						time_ena <= '1';
						if pressed = '1' and key_data = 6 then
							lcd_mod_count <= 3;
						end if;
						if msec < 500 then
							lcd_flash <= '0';
						elsif msec < 1000 then
							lcd_flash <= '1';
						elsif msec = 1000 then
							time_ena <= '0';
						end if;
					elsif lcd_mod_count = 3 then
						if mod11 = '1' then
							tts_ena <= '1';
							tts_data(0 to 21) <= tts2;
							tts_len <= 22;
							if tts_busy = '1' then
								tts_ena <= '0';
							end if;
						end if;
						time_ena <= '0';
						if pressed = '1' then
							if mod11 = '1' then
								tts_ena <= '1';
								tts_data(0 to 21) <= tts2;
								tts_len <= 22;
								if tts_busy = '1' then
									tts_ena <= '0';
								end if;
							end if;
							if key_data = 4 then
								if vol /= 0 then
									vol <= vol - 1;
								else
									vol <= 0;
								end if;
							elsif key_data = 5 then
								if vol /= 99 then
									vol <= vol + 1;
								else
									vol <= 99;
								end if;
							elsif key_data = 3 then
								lcd_mod_count <= 4;
							end if;
						end if;
					elsif lcd_mod_count = 4 then
						if mod11 = '1' then
							tts_ena <= '1';
							tts_data(0 to 21) <= tts2;
							tts_len <= 22;
							if tts_busy = '1' then
								tts_ena <= '0';
							end if;
						end if;
						time_ena <= '1';
						if pressed = '1' and key_data = 6 then
							s5_mem <= 0;
							lcd_mod_count <= 5;
						end if;
						if msec < 500 then
							lcd_flash <= '0';
						elsif msec < 1000 then
							lcd_flash <= '1';
						elsif msec = 1000 then
							time_ena <= '0';
						end if;
					elsif lcd_mod_count = 5 then
						time_ena <= '0';
						tts_ena <= '0';
						if pressed = '1' then
							if key_data = 6 then
								tts_ena <= '1';
								if s5_mem = 0 then
									tts_data(0 to 4) <= music1;
									tts_len <= 5;
									lcd_mod_count <= 6;
								elsif s5_mem = 1 then
									tts_data(0 to 4) <= music3;
									tts_len <= 5;
									lcd_mod_count <= 6;
								elsif s5_mem = 2 then
									tts_data(0 to 4) <= music2;
									tts_len <= 5;
									lcd_mod_count <= 6;
								end if;
							elsif key_data = 4 then
								if s5_mem < 2 then
									s5_mem <= s5_mem + 1;
								else
									s5_mem <= 0;
								end if;
							end if;
						end if;
					elsif lcd_mod_count = 6 then
						if tts_busy = '1' then
							tts_ena <= '0';
						end if;
						if pressed = '1' and key_data = 3 then
							s4_mem <= '1';
						end if;
						if clk_1hz = '1' then
							music_sec <= music_sec + 1;
							if music_sec = music_sec'high then
								music_sec <= 0;
								if music_min = music_min'high then
									music_min <= 0;
								else
									music_min <= music_min + 1;
								end if;
							end if;
						end if;
						if s4_mem = '1' then
							time_ena <= '1';
							if msec < 500 then
								lcd_flash <= '0';
							elsif msec < 1000 then
								lcd_flash <= '1';
							elsif msec = 1000 then
								time_ena <= '0';
							end if;
							if pressed = '1' and key_data = 6 then
								time_ena <= '0';
								pause <= '0';
								lcd_mod_count <= 7;
							end if;
						end if;
					elsif lcd_mod_count = 7 then
						if mod11 = '1' and pause = '0' then
							tts_ena <= '1';
							tts_data(0 to 11) <= tts3;
							tts_len <= 12;
							if tts_done = '1' then
								time_ena <= '1';
								pause <= '1';
								tts_ena <= '0';
							end if;
						elsif msec >= 3000 and pause = '1' then
							tts_ena <= '1';
							tts_data(0 to 11) <= tts4;
							tts_len <= 12;
						end if;
						music_sec <= 0;
						music_min <= 0;
						if pressed = '1' and key_data = 3 then
							tts_ena <= '0';
							pause <= '0';
							lcd_mod_count <= 0;
						end if;
					end if;
					case lcd_count is
						when 0 => -- white
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
									color <= all_green;
									y <= 10;
									lcd_count <= 1;
								end if;
							end if;
						when 1 =>
							if lcd_mod_count = 0 then
								if lcd_flash = '1' then
									color <= F1_0;
								else
									color <= all_green;
								end if;
							elsif lcd_mod_count = 1 then
								color <= F1_1;
							elsif lcd_mod_count = 2 then
								if lcd_flash = '1' then
									color <= F1_0;
								else
									color <= all_green;
								end if;
							elsif lcd_mod_count = 3 then
								color <= F2_red;
							elsif lcd_mod_count = 4 then
								if lcd_flash = '1' then
									color <= N_0;
								else
									color <= all_green;
								end if;
							elsif lcd_mod_count = 5 then
								color <= N_red;
							elsif lcd_mod_count = 6 then
								if s4_mem = '1' then
									if lcd_flash = '1' then
										color <= P_0;
									else
										color <= all_green;
									end if;
								end if;
							elsif lcd_mod_count = 7 then
								color <= P_red;
							end if;
							lcd_clear <= '0';
							if y = 10 and lcd_mod_count < 2 then
								data <= " F1 , N , P ";
								font_start <= '1';
							elsif y = 10 and lcd_mod_count >= 2 then
								data <= " F2 , N , P ";
								font_start <= '1';
							end if;
							if draw_done = '1' then
								color <= all_green;
								font_start <= '0';
								y <= 30;
								lcd_count <= 2;
							end if;
						when 2 =>
							if lcd_mod_count = 1 then
								color <= all_blue;
							elsif lcd_mod_count = 4 then
								color <= P1_blue;
							elsif lcd_mod_count = 5 then
								if s5_mem /= 0 then
									color <= all_red;
								else
									color <= file_blue;
								end if;
							end if;
							if y = 30 then
								data <= "File1:P1.wav";
								font_start <= '1';
							end if;
							if draw_done = '1' then
								color <= all_green;
								font_start <= '0';
								y <= 50;
								lcd_count <= 3;
							end if;
						when 3 =>
							if lcd_mod_count = 1 then
								color <= all_blue;
							elsif lcd_mod_count = 5 then
								if s5_mem /= 1 then
									color <= all_red;
								else
									color <= all_blue;
								end if;
							end if;
							if y = 50 then
								data <= "      P2.wav";
								font_start <= '1';
							end if;
							if draw_done = '1' then
								color <= all_green;
								font_start <= '0';
								y <= 70;
								lcd_count <= 4;
							end if;
						when 4 =>
							if lcd_mod_count = 1 then
								color <= all_blue;
							elsif lcd_mod_count = 5 then
								if s5_mem /= 2 then
									color <= all_red;
								else
									color <= all_blue;
								end if;
							end if;
							if y = 70 then
								data <= "      P3.wav";
								font_start <= '1';
							end if;
							if draw_done = '1' then
								color <= all_green;
								font_start <= '0';
								y <= 90;
								lcd_count <= 5;
							end if;
						when 5 =>
							if lcd_mod_count = 3 then
								color <= all_red;
							end if;
							if y = 90 then
								data <= "Vol. :" & to_string(vol, vol'high, 10, 2) & "    ";
								font_start <= '1';
							end if;
							if draw_done = '1' then
								color <= all_green;
								font_start <= '0';
								y <= 110;
								lcd_count <= 6;
							end if;
						when 6 =>
							if lcd_mod_count = 5 then
								color <= all_red;
							elsif lcd_mod_count = 7 then
								color <= all_red;
							end if;
							if y = 110 then
								data <= "T    :" & to_string(music_min, music_min'high, 10, 2) & ':' & to_string(music_sec, music_sec'high, 10, 2) & ' ';
								font_start <= '1';
							end if;
							if draw_done = '1' then
								color <= all_green;
								font_start <= '0';
								y <= 10;
								lcd_count <= 1;
							end if;
						when others => null;
					end case;
				when stop =>
					seg_data <= "        ";
					lcd_count <= 0;
					time_ena <= '0';
				when lcd_stop =>
					load <= msec;
					time_ena <= '0';
			end case;
		end if;
	end process;
end architecture;

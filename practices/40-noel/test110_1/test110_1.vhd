library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;

entity test110_1 is
	port (
		-- system
		clk   : in std_logic;
		rst_n : in std_logic;
		-- LCD
		lcd_sclk, lcd_mosi, lcd_ss_n, lcd_dc, lcd_bl, lcd_rst_n : out std_logic;
		-- seg
		seg_led, seg_com : out u8r_t;
		-- sw
		sw : in u8r_t;
		-- key
		key_row : in u4r_t;
		key_col : out u4r_t;
		--tts
		tts_scl, tts_sda : inout std_logic;
		tts_mo           : in unsigned(2 downto 0);
		tts_rst_n        : out std_logic;
		-- dht
		dht_data : inout std_logic
	);
end test110_1;

architecture arch of test110_1 is
	type mode_t is (res, mod0, mod1, mod2, mod3);
	signal mode : mode_t;
	type tts_mode_t is(idle, send, stop);
	signal tts_mode : tts_mode_t;
	--
	signal clk1, clk_1hz, flash : std_logic;
	--
	signal temp_high, hum_high, temp_high_m, hum_high_m : integer range 0 to 99;
	signal hour : integer range 0 to 24;
	signal minute, second : integer range 0 to 59;
	-- flag
	signal stop_flag : std_logic; -- when 1 => test stop
	signal time_system_flag, time_system_flag_m : std_logic; -- when 1 => 12 hour time system, when 0 => 24 hour time system
	signal time_change_flag, time_save_flag : std_logic;
	signal temp_change_flag, temp_save_flag : std_logic;
	signal hum_change_flag, hum_save_flag : std_logic;
	signal back3_flag, back4_flag, back5_flag, back6_flag : std_logic;
	signal sw_1_flag, sw_2_flag, sw_3_flag : std_logic;
	signal start_flag : std_logic;
	-- LCD
	signal x : integer range -127 to 127;
	signal y : integer range -159 to 159;
	signal font_start, font_busy, draw_done : std_logic;
	signal text_data : string(1 to 12);
	signal l_addr : l_addr_t;
	signal bg_color : l_px_t;
	signal text_color : l_px_arr_t(1 to 12);
	signal lcd_clear : std_logic;
	signal lcd_con : std_logic;
	signal pic_addr : l_addr_t;
	signal pic_data : l_px_t;

	signal lcd_count : integer range 0 to 10;

	constant all_green : l_px_arr_t(1 to 12) := (green, green, green, green, green, green, green, green, green, green, green, green);
	constant all_blue : l_px_arr_t(1 to 12) := (blue, blue, blue, blue, blue, blue, blue, blue, blue, blue, blue, blue);
	constant temp_blue : l_px_arr_t(1 to 12) := (blue, blue, blue, blue, blue, blue, green, green, green, green, green, green);
	constant hum_blue : l_px_arr_t(1 to 12) := (green, green, green, green, green, green, blue, blue, blue, blue, blue, blue);
	--key
	signal pressed_i, key_pressed : std_logic;
	signal key_data : i4_t;
	-- seg
	signal seg_data : string(1 to 8);
	signal seg_dot : u8r_t;
	-- dht
	signal temp_int, hum_int : integer range 0 to 99;
	-- tts
	constant txt_len_max : integer := 100;
	signal tts_ena, tts_busy : std_logic;
	signal tts_data : u8_arr_t(0 to txt_len_max - 1);
	signal tts_len : integer range 0 to txt_len_max;
	signal tts_count : integer range 0 to 10;

	-- (空白)
	constant blank : u8_arr_t(0 to 1) := (x"20", x"20");
	-- 系統開機於
	constant tts_start : u8_arr_t(0 to 36) := (
        x"a8", x"74", x"b2", x"ce", x"b6", x"7d", x"be", x"f7", x"a9", x"f3", x"a4", x"40", x"a6", x"ca", x"a4", x"40",
        x"a4", x"51", x"a4", x"47", x"a6", x"7e", x"a4", x"51", x"a4", x"40", x"a4", x"eb", x"a4", x"51", x"a4", x"43",
        x"a4", x"e9", x"66", x"72", x"69"
);
	-- 時
	constant tts_hour : u8_arr_t(0 to 1) := (x"ae", x"c9");
	-- 分
	constant tts_min : u8_arr_t(0 to 1) := (x"a4", x"c0");
	-- 秒
	constant tts_sec : u8_arr_t(0 to 1) := (x"ac", x"ed");
	-- 溫度為
	constant tts_temp : u8_arr_t(0 to 5) := (x"b7", x"c5", x"ab", x"d7", x"ac", x"b0");
	-- 濕度為
	constant tts_hum : u8_arr_t(0 to 5) := (x"c0", x"e3", x"ab", x"d7", x"ac", x"b0");
	-- 正常
	constant tts_normal : u8_arr_t(0 to 3) := (x"a5", x"bf", x"b1", x"60");
	-- 過高
	constant tts_high : u8_arr_t(0 to 3) := (x"b9", x"4c", x"b0", x"aa");

	-- timer
	signal timer_ena : std_logic;
	signal timer_load : i32_t;
	signal timer_msec : i32_t;
begin
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
			addr             => l_addr,
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
	edge_lcd_inst : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => font_busy,
			rising  => open,
			falling => draw_done
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
	edge_key_inst : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => pressed_i,
			rising  => key_pressed,
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
			temp_dec => open,
			hum_dec  => open
		);
	tts_stop_inst : entity work.tts_stop(arch)
		generic map(
			txt_len_max => txt_len_max
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
			stop_speak => open,
			txt        => tts_data,
			txt_len    => tts_len
		);
	timer_inst : entity work.timer(arch)
		port map(
			clk   => clk,
			rst_n => rst_n,
			ena   => timer_ena,
			load  => timer_load,
			msec  => timer_msec
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
	edge_sw1_inst: entity work.edge(arch)
		port map (
			clk 	=> 	clk,
			rst_n   => rst_n,
			sig_in  => sw(3),
			rising  => sw_1_flag,
			falling => open 
		);
	edge_sw2_inst: entity work.edge(arch)
		port map (
			clk 	=> 	clk,
			rst_n   => rst_n,
			sig_in  => sw(2),
			rising  => sw_2_flag,
			falling => open 
		);
	edge_sw3_inst: entity work.edge(arch)
		port map (
			clk 	=> 	clk,
			rst_n   => rst_n,
			sig_in  => sw(1),
			rising  => sw_3_flag,
			falling => open 
		);
	process (clk, rst_n)
	begin
		if rst_n = '0' or (key_pressed = '1' and key_data = 1) then
			time_system_flag <= '0';
			stop_flag <= '0';

			lcd_count <= 0;
			temp_high_m <= 28;
			hum_high_m <= 80;
			temp_high <= 28;
			hum_high <= 80;
			timer_load <= 0;
			timer_ena <= '0';
			timer_load <= 0;
			lcd_clear <= '1';
			lcd_con <= '0';
			tts_ena <= '0';
			seg_data <= "        ";
			seg_dot <= "00000000";
			mode <= res;
		elsif rising_edge(clk) then
			if key_pressed = '1' and key_data = 0 then
				if time_change_flag = '1' and time_save_flag = '0' then
					time_system_flag <= time_system_flag_m;
				end if;
				if temp_change_flag = '1' and temp_save_flag = '0' then
					temp_high <= temp_high_m;
				end if;
				if sw(6 to 7) = "00" then
					mode <= mod0;
				elsif sw(6 to 7) = "01" then
					lcd_count <= 0;
					time_change_flag <= '0';
					time_save_flag <= '0';
					temp_change_flag <= '0';
					temp_save_flag <= '0';
					hum_change_flag <= '0';
					hum_save_flag <= '0';
					lcd_clear <= '1';
					mode <= mod1;
				elsif sw(6 to 7) = "10" then
					lcd_count <= 0;
					mode <= mod2;
				elsif sw(6 to 7) = "11" then
					start_flag <= '1';
					lcd_count <= 0;
					tts_count <= 0;
					mode <= mod3;
				end if;
			end if;
			case mode is
				when res =>
					bg_color <= white;
				when mod0 =>
					if key_pressed = '1' and key_data = 0 then
						if stop_flag = '0' then
							stop_flag <= '1';
							timer_load <= timer_msec;
						else
							stop_flag <= '0';
						end if;
					elsif timer_msec /= 11000 and stop_flag = '0' then
						timer_ena <= '1';
					elsif timer_msec >= 11000 then
						lcd_count <= 0;
						timer_load <= 0;
						timer_ena <= '0';
					elsif stop_flag = '1' then
						timer_ena <= '0';
					end if;
					case lcd_count is
						when 0 =>
							lcd_con <= '0';
							lcd_clear <= '1';
							bg_color <= red;
							if font_busy = '0' and timer_msec = 1000 and stop_flag = '0' then
								lcd_count <= 1;
							end if;
						when 1 =>
							bg_color <= white;
							if font_busy = '0' and timer_msec = 2000 and stop_flag = '0' then
								lcd_count <= 2;
								font_start <= '0';
							end if;
						when 2 =>
							x <= 5;
							y <= 0;
							lcd_clear <= '0';
							text_color <= all_green;
							if timer_msec >= 5000 then
								text_data <= "  Wed.  Sun.";
							elsif timer_msec >= 3000 then
								text_data <= "  Wed.      ";
							else
								text_data <= "            ";
							end if;
							font_start <= '1';
							if draw_done = '1' then
								font_start <= '0';
								lcd_count <= 3;
							end if;
						when 3 =>
							y <= 20;
							if timer_msec >= 5000 then
								text_data <= " 1 3  5  7  ";
							elsif timer_msec >= 4000 then
								text_data <= " 1 3  5     ";
							elsif timer_msec >= 3000 then
								text_data <= " 1 3        ";
							elsif timer_msec >= 2000 then
								text_data <= " 1          ";
							else
								text_data <= "            ";
							end if;
							font_start <= '1';
							if draw_done = '1' then
								font_start <= '0';
								lcd_count <= 4;
							end if;
						when 4 =>
							y <= 40;
							if timer_msec >= 4000 then
								text_data <= "Mon. Fri.   ";
							elsif timer_msec >= 2000 then
								text_data <= "Mon.        ";
							else
								text_data <= "            ";
							end if;
							font_start <= '1';
							if draw_done = '1' then
								font_start <= '0';
								lcd_count <= 5;
							end if;
						when 5 =>
							y <= 60;
							if timer_msec >= 9000 then
								text_data <= "  Tue.  Sat.";
							elsif timer_msec >= 7000 then
								text_data <= "  Tue.      ";
							else
								text_data <= "            ";
							end if;
							font_start <= '1';
							if draw_done = '1' then
								font_start <= '0';
								lcd_count <= 6;
							end if;
						when 6 =>
							y <= 80;
							if timer_msec >= 9000 then
								text_data <= " 9 2  4  6  ";
							elsif timer_msec >= 8000 then
								text_data <= " 9 2  4     ";
							elsif timer_msec >= 7000 then
								text_data <= " 9 2        ";
							elsif timer_msec >= 6000 then
								text_data <= " 9          ";
							else
								text_data <= "            ";
							end if;
							font_start <= '1';
							if draw_done = '1' then
								font_start <= '0';
								lcd_count <= 7;
							end if;
						when 7 =>
							y <= 100;
							if timer_msec >= 8000 then
								text_data <= " :   Thu.   ";
							elsif timer_msec >= 6000 then
								text_data <= " :          ";
							else
								text_data <= "            ";
							end if;
							font_start <= '1';
							if draw_done = '1' then
								font_start <= '0';
								lcd_count <= 8;
							end if;
						when 8 =>
							y <= 117;
							if timer_msec >= 10000 then
								text_data <= " 8          ";
							else
								text_data <= "            ";
							end if;
							font_start <= '1';
							if draw_done = '1' then
								font_start <= '0';
								lcd_count <= 9;
							end if;
						when 9 =>
							y <= 130;
							if timer_msec >= 10000 then
								text_data <= "o           ";
							else
								text_data <= "            ";
							end if;
							font_start <= '1';
							if draw_done = '1' then
								font_start <= '0';
								lcd_count <= 10;
							end if;
						when 10 =>
							y <= 142;
							if timer_msec >= 10000 then
								text_data <= " C          ";
							else
								text_data <= "            ";
							end if;
							font_start <= '1';
							if draw_done = '1' then
								font_start <= '0';
								lcd_count <= 2;
							end if;
					end case;
				when mod1 =>
					lcd_clear <= '1';
					bg_color <= white;
					case sw(0 to 3) is
						when "0000" =>
							seg_data <= "0000MODE";
							seg_dot <= "01000000";
						when "0001" =>
							if key_pressed = '1' and key_data = 3 then
								time_system_flag <= not time_system_flag;
								time_change_flag <= '1';
								time_save_flag <= '0';
							elsif key_pressed = '1' and key_data = 6 then
								time_system_flag_m <= time_system_flag;
								time_save_flag <= '1';
							elsif time_system_flag = '0' then
								seg_data <= "0124MODE";
								seg_dot <= "01000000";
							elsif time_system_flag = '1' then
								seg_data <= "0112MODE";
								seg_dot <= "01000000";
							end if;
						when "0010" =>
							seg_data <= "02" & to_string(temp_high, 99, 10, 2) & "MODE";
							seg_dot <= "01000000";
							if key_pressed = '1' and key_data = 4 then
								temp_change_flag <= '1';
								temp_save_flag <= '0';
								if temp_high /= 0 then
									temp_high <= temp_high - 1;
								else
									temp_high <= 0;
								end if;
							elsif key_pressed = '1' and key_data = 5 then
								temp_change_flag <= '1';
								temp_save_flag <= '0';
								if temp_high /= 99 then
									temp_high <= temp_high + 1;
								else
									temp_high <= 99;
								end if;
							elsif key_pressed = '1' and key_data = 6 then
								temp_high_m <= temp_high;
								temp_save_flag <= '1';
							end if;
						when "0100" =>
							seg_data <= "02" & to_string(hum_high, 99, 10, 2) & "MODE";
							seg_dot <= "01000000";
							if key_pressed = '1' and key_data = 4 then
								hum_change_flag <= '1';
								hum_save_flag <= '0';
								if hum_high /= 0 then
									hum_high <= hum_high - 1;
								else
									hum_high <= 0;
								end if;
							elsif key_pressed = '1' and key_data = 5 then
								hum_change_flag <= '1';
								hum_save_flag <= '0';
								if hum_high /= 99 then
									hum_high <= hum_high + 1;
								else
									hum_high <= 99;
								end if;
							elsif key_pressed = '1' and key_data = 6 then
								temp_save_flag <= '1';
								hum_high_m <= hum_high;
							end if;
						when others =>
							seg_data <= "0000MODE";
							seg_dot <= "01000000";
					end case;
				when mod2 =>
					case sw(0 to 3) is
						when "0000" =>
							seg_data <= "0000MODE";
							seg_dot <= "01000000";
						when "0001" =>
							if key_pressed = '1' and key_data = 3 then
								time_system_flag <= not time_system_flag;
								time_change_flag <= '1';
								time_save_flag <= '0';
							elsif key_pressed = '1' and key_data = 6 then
								time_system_flag_m <= time_system_flag;
								time_save_flag <= '1';
							elsif time_system_flag = '0' then
								seg_data <= "0124MODE";
								seg_dot <= "01000000";
							elsif time_system_flag = '1' then
								seg_data <= "0112MODE";
								seg_dot <= "01000000";
							end if;
						when "0010" =>
							seg_data <= "02" & to_string(temp_high, 99, 10, 2) & "MODE";
							seg_dot <= "01000000";
							if key_pressed = '1' and key_data = 4 then
								temp_change_flag <= '1';
								temp_save_flag <= '0';
								if temp_high /= 0 then
									temp_high <= temp_high - 1;
								else
									temp_high <= 0;
								end if;
							elsif key_pressed = '1' and key_data = 5 then
								temp_change_flag <= '1';
								temp_save_flag <= '0';
								if temp_high /= 99 then
									temp_high <= temp_high + 1;
								else
									temp_high <= 99;
								end if;
							elsif key_pressed = '1' and key_data = 6 then
								temp_high_m <= temp_high;
								temp_save_flag <= '1';
							end if;
						when "0100" =>
							seg_data <= "02" & to_string(hum_high, 99, 10, 2) & "MODE";
							seg_dot <= "01000000";
							if key_pressed = '1' and key_data = 4 then
								hum_change_flag <= '1';
								hum_save_flag <= '0';
								if hum_high /= 0 then
									hum_high <= hum_high - 1;
								else
									hum_high <= 0;
								end if;
							elsif key_pressed = '1' and key_data = 5 then
								hum_change_flag <= '1';
								hum_save_flag <= '0';
								if hum_high /= 99 then
									hum_high <= hum_high + 1;
								else
									hum_high <= 99;
								end if;
							elsif key_pressed = '1' and key_data = 6 then
								temp_save_flag <= '1';
								hum_high_m <= hum_high;
							end if;
						when others =>
							seg_data <= "0000MODE";
							seg_dot <= "01000000";
					end case;
					if clk_1hz = '1' then
						if second /= 59 then
							second <= second + 1;
						else
							second <= 0;
							if minute /= 59 then
								minute <= minute + 1;
							else
								minute <= 0;
								if hour /= 12 then
									hour <= hour + 1;
								else
									hour <= 0;
								end if;
							end if;
						end if;
						flash <= not flash;
					end if;
					case lcd_count is
						when 0 =>
							lcd_con <= '0';
							lcd_clear <= '1';
							bg_color <= white;
							if draw_done = '1' then
								font_start <= '0';
								lcd_count <= 1;
							end if;
						when 1 =>
							lcd_clear <= '0';
							x <= 5;
							y <= 5;
							text_color <= all_green;
							text_data <= "1121117Fri. ";
							font_start <= '1';
							if draw_done = '1' then
								font_start <= '0';
								lcd_count <= 2;
							end if;
						when 2 =>
							y <= 35;
							if time_system_flag = '1' then
								text_data <= "  " & to_string(hour, 99, 10, 2) & ":" & to_string(minute, 99, 10, 2) & ":" & to_string(second, 99, 10, 2) & "  ";
							else
								text_data <= "  " & to_string(hour + 12, 99, 10, 2) & ":" & to_string(minute, 99, 10, 2) & ":" & to_string(second, 99, 10, 2) & "  ";
							end if;
							font_start <= '1';
							if draw_done = '1' then
								font_start <= '0';
								lcd_count <= 3;
							end if;
						when 3 =>
							y <= 55;
							if temp_int < temp_high and hum_int < hum_high then
								text_data <= "  " & to_string(temp_int, 99, 10, 2) & " C  " & to_string(hum_int, 99, 10, 2) & "  ";
								text_color <= all_green;
							elsif temp_int < temp_high and hum_int >= hum_high then
								if flash = '0' then
									text_data <= "  " & to_string(temp_int, 99, 10, 2) & " C  " & "    ";
								else
									text_data <= "  " & to_string(temp_int, 99, 10, 2) & " C  " & to_string(hum_int, 99, 10, 2) & "  ";
								end if;
								text_color <= hum_blue;
							elsif temp_int >= temp_high and hum_int < hum_high then
								if flash = '0' then
									text_data <= "        " & to_string(hum_int, 99, 10, 2) & "  ";
								else
									text_data <= "  " & to_string(temp_int, 99, 10, 2) & " C  " & to_string(hum_int, 99, 10, 2) & "  ";
								end if;
								text_color <= temp_blue;
							elsif temp_int >= temp_high and hum_int >= hum_high then
								if flash = '0' then
									text_data <= "            ";
								else
									text_data <= "  " & to_string(temp_int, 99, 10, 2) & " C  " & to_string(hum_int, 99, 10, 2) & "  ";
								end if;
								text_color <= all_blue;
							end if;
							font_start <= '1';
							if draw_done = '1' then
								font_start <= '0';
								lcd_count <= 4;
							end if;
						when 4 =>
							y <= 90;
							text_color <= all_green;
							if time_system_flag = '1' then
								text_data <= "        12  ";
							else
								text_data <= "        24  ";
							end if;
							font_start <= '1';
							if draw_done = '1' then
								font_start <= '0';
								lcd_count <= 1;
							end if;
						when others =>
					end case;
				when mod3 =>
					if sw_1_flag = '1' or sw_2_flag = '1' or sw_3_flag = '1' then
						tts_count <= 8;
						if sw_1_flag = '1' then
							back4_flag <= '1';
							back5_flag <= '0';
							back6_flag <= '0';
						elsif sw_2_flag = '1' then
							back4_flag <= '0';
							back5_flag <= '1';
							back6_flag <= '0';
						elsif sw_3_flag = '1' then
							back4_flag <= '0';
							back5_flag <= '0';
							back6_flag <= '1';
						end if;
					end if;
						case sw(0 to 3) is
						when "0000" =>
							seg_data <= "0000MODE";
							seg_dot <= "01000000";
						when "0001" =>
							-- back4_flag <= '1';
							if key_pressed = '1' and key_data = 3 then
								time_system_flag <= not time_system_flag;
								time_change_flag <= '1';
								time_save_flag <= '0';
							elsif key_pressed = '1' and key_data = 6 then
								time_system_flag_m <= time_system_flag;
								time_save_flag <= '1';
							elsif time_system_flag = '0' then
								seg_data <= "0124MODE";
								seg_dot <= "01000000";
							elsif time_system_flag = '1' then
								seg_data <= "0112MODE";
								seg_dot <= "01000000";
							end if;
						when "0010" =>
							-- back5_flag <= '1';
							seg_data <= "02" & to_string(temp_high, 99, 10, 2) & "MODE";
							seg_dot <= "01000000";
							if key_pressed = '1' and key_data = 4 then
								temp_change_flag <= '1';
								temp_save_flag <= '0';
								if temp_high /= 0 then
									temp_high <= temp_high - 1;
								else
									temp_high <= 0;
								end if;
							elsif key_pressed = '1' and key_data = 5 then
								temp_change_flag <= '1';
								temp_save_flag <= '0';
								if temp_high /= 99 then
									temp_high <= temp_high + 1;
								else
									temp_high <= 99;
								end if;
							elsif key_pressed = '1' and key_data = 6 then
								temp_high_m <= temp_high;
								temp_save_flag <= '1';
							end if;
						when "0100" =>
							-- back6_flag <= '1';
							seg_data <= "02" & to_string(hum_high, 99, 10, 2) & "MODE";
							seg_dot <= "01000000";
							if key_pressed = '1' and key_data = 4 then
								hum_change_flag <= '1';
								hum_save_flag <= '0';
								if hum_high /= 0 then
									hum_high <= hum_high - 1;
								else
									hum_high <= 0;
								end if;
							elsif key_pressed = '1' and key_data = 5 then
								hum_change_flag <= '1';
								hum_save_flag <= '0';
								if hum_high /= 99 then
									hum_high <= hum_high + 1;
								else
									hum_high <= 99;
								end if;
							elsif key_pressed = '1' and key_data = 6 then
								temp_save_flag <= '1';
								hum_high_m <= hum_high;
							end if;
						when others =>
							seg_data <= "0000MODE";
							seg_dot <= "01000000";
					end case;
					if clk_1hz = '1' then
						if second /= 59 then
							second <= second + 1;
						else
							second <= 0;
							if minute /= 59 then
								minute <= minute + 1;
							else
								minute <= 0;
								if hour /= 12 then
									hour <= hour + 1;
								else
									hour <= 0;
								end if;
							end if;
						end if;
						flash <= not flash;
					end if;
					case lcd_count is
						when 0 =>
							lcd_con <= '0';
							lcd_clear <= '1';
							bg_color <= white;
							if draw_done = '1' then
								font_start <= '0';
								lcd_count <= 1;
							end if;
						when 1 =>
							lcd_clear <= '0';
							x <= 5;
							y <= 5;
							text_color <= all_green;
							text_data <= "1121117Fri. ";
							font_start <= '1';
							if draw_done = '1' then
								font_start <= '0';
								lcd_count <= 2;
							end if;
						when 2 =>
							y <= 35;
							if time_system_flag = '1' then
								text_data <= "  " & to_string(hour, 99, 10, 2) & ":" & to_string(minute, 99, 10, 2) & ":" & to_string(second, 99, 10, 2) & "  ";
							else
								text_data <= "  " & to_string(hour + 12, 99, 10, 2) & ":" & to_string(minute, 99, 10, 2) & ":" & to_string(second, 99, 10, 2) & "  ";
							end if;
							font_start <= '1';
							if draw_done = '1' then
								font_start <= '0';
								lcd_count <= 3;
							end if;
						when 3 =>
							y <= 55;
							if temp_int < temp_high and hum_int < hum_high then
								text_data <= "  " & to_string(temp_int, 99, 10, 2) & " C  " & to_string(hum_int, 99, 10, 2) & "  ";
								text_color <= all_green;
							elsif temp_int < temp_high and hum_int >= hum_high then
								if flash = '0' then
									text_data <= "  " & to_string(temp_int, 99, 10, 2) & " C  " & "    ";
								else
									text_data <= "  " & to_string(temp_int, 99, 10, 2) & " C  " & to_string(hum_int, 99, 10, 2) & "  ";
								end if;
								text_color <= hum_blue;
							elsif temp_int >= temp_high and hum_int < hum_high then
								if flash = '0' then
									text_data <= "        " & to_string(hum_int, 99, 10, 2) & "  ";
								else
									text_data <= "  " & to_string(temp_int, 99, 10, 2) & " C  " & to_string(hum_int, 99, 10, 2) & "  ";
								end if;
								text_color <= temp_blue;
							elsif temp_int >= temp_high and hum_int >= hum_high then
								if flash = '0' then
									text_data <= "            ";
								else
									text_data <= "  " & to_string(temp_int, 99, 10, 2) & " C  " & to_string(hum_int, 99, 10, 2) & "  ";
								end if;
								text_color <= all_blue;
							end if;
							font_start <= '1';
							if draw_done = '1' then
								font_start <= '0';
								lcd_count <= 4;
							end if;
						when 4 =>
							y <= 90;
							text_color <= all_green;
							if time_system_flag = '1' then
								text_data <= "        12  ";
							else
								text_data <= "        24  ";
							end if;
							font_start <= '1';
							if draw_done = '1' then
								font_start <= '0';
								lcd_count <= 1;
							end if;
						when others =>
					end case;
					case tts_mode is
						when idle =>
							if tts_busy = '0' then
								tts_mode <= send;
							end if;
						when send =>
							case tts_count is
								when 0 =>
									tts_data(0 to 1) <= tts_instant_soft_reset;
									tts_len <= 2;
									tts_ena <= '1';
								when 1 =>
									tts_data(0 to 1) <= tts_instant_soft_reset;
									tts_len <= 2;
									tts_ena <= '1';
								when 2 =>
									tts_data(0 to 1) <= blank;
									tts_len <= 2;
									tts_ena <= '1';
								when 3 =>
									tts_data(0 to 36) <= tts_start;
									tts_len <= 37;
									tts_ena <= '1';
								when 4 =>
									if time_system_flag = '1' then
										tts_data(0 to 23) <= to_big(hour) & tts_hour & to_big(minute) & tts_min & to_big(second) & tts_sec;
									else
										tts_data(0 to 23) <= to_big(hour + 12) & tts_hour & to_big(minute) & tts_min & to_big(second) & tts_sec;
									end if;
									tts_len <= 24;
									tts_ena <= '1';
								when 5 =>
									if temp_int >= temp_high then
										tts_data(0 to 15) <= tts_temp & to_big(temp_int) & tts_high;
									else
										tts_data(0 to 15) <= tts_temp & to_big(temp_int) & tts_normal;
									end if;
									tts_len <= 16;
									tts_ena <= '1';
								when 6 =>
									if hum_int >= hum_high then
										tts_data(0 to 15) <= tts_hum & to_big(hum_int) & tts_high;
									else
										tts_data(0 to 15) <= tts_hum & to_big(hum_int) & tts_normal;
									end if;
									tts_len <= 16;
									tts_ena <= '1';
								when 7 =>
									tts_data(0 to 1) <= blank;
									tts_len <= 2;
									tts_ena <= '1';
								when 8 =>
									tts_data(0 to 1) <= tts_instant_soft_reset;
									tts_len <= 2;
									tts_ena <= '1';
								when 9 =>
									tts_data(0 to 1) <= tts_instant_soft_reset;
									tts_len <= 2;
									tts_ena <= '1';
								when 10 =>
									tts_data(0 to 1) <= blank;
									tts_len <= 2;
									tts_ena <= '1';
							end case;
							if tts_busy = '1' then
								tts_mode <= stop;
								tts_ena <= '0';
							end if;
						when stop =>
							if tts_count = 0 then
								tts_count <= 1;
							elsif tts_count = 1 then
								tts_count <= 2;
							elsif tts_count = 2 and start_flag = '1' then
								tts_count <= 3;
								start_flag <= '0';
							elsif tts_count = 3 then
								tts_count <= 7;
							elsif tts_count = 8 then
								tts_count <= 9;
							elsif tts_count = 9 then
								tts_count <= 10;
							elsif tts_count = 10 and back4_flag = '1' then
								tts_count <= 4;
							elsif tts_count = 10 and back5_flag = '1' then
								tts_count <= 5;
							elsif tts_count = 10 and back6_flag = '1' then
								tts_count <= 6;
							-- elsif tts_count = 4 then
							-- 	tts_count <= 4;
							-- elsif tts_count = 5 then
							-- 	tts_count <= 5;
							-- elsif tts_count = 6 then
							-- 	tts_count <= 6;
							end if;
							tts_ena <= '0';
							tts_mode <= idle;
					end case;
			end case;
		end if;
	end process;
end arch;

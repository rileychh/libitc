library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;

entity itc112_1 is
	port (
		clk   : in std_logic;
		rst_n : in std_logic;
		--seg
		seg_led, seg_com : out u8r_t;
		--sw
		sw : in u8r_t;
		--key
		key_row : in u4r_t;
		key_col : out u4r_t;
		--lcd
		lcd_sclk, lcd_mosi, lcd_ss_n, lcd_dc, lcd_bl, lcd_rst_n : out std_logic;
		--tts
		tts_scl, tts_sda : inout std_logic;
		tts_mo           : in unsigned(2 downto 0);
		tts_rst_n        : out std_logic
	);
end itc112_1;

architecture arch of itc112_1 is
	signal clk_1, clk_1hz, clk_2, clk_2hz, clk_3, clk_3hz, clk_5, clk_5hz, test_clk : std_logic;
	signal mix_mod : std_logic;

	signal stop_flag : std_logic; -- when '1' => stop
	signal x_set_flag, y_set_flag : std_logic; -- when '1' => set sucess
	signal xy_set_mod : std_logic; -- when '0' => set x, when '1' => set y
	signal x_change_flag, y_change_flag, color_change_flag : std_logic; -- when '1' => x or y or color is changed

	type mode is (res, mod0, mod1, mod2, tts_res, lcd_stop);
	signal mode_t : mode;
	type seg_mod is (xy_set, col_set);
	signal seg_mod_t : seg_mod;

	--seg
	signal seg_data : string(1 to 8);
	signal seg_dot : u8r_t;
	--key
	signal pressed_i, key_pressed : std_logic;
	signal key_data : i4_t;
	--lcd
	signal x, l_x, l_x_m1, l_x_m2 : integer range -127 to 127;
	signal y, l_y, l_y_m1, l_y_m2 : integer range -159 to 159;
	signal col_setup : std_logic; -- set sucess
	signal col_mod : integer range 0 to 2; -- 0 = green, 1 = red, 2 = blue
	signal pic_col : l_px_t; -- can set pic clolor 
	signal font_start, font_busy : std_logic;
	signal text_data : string(1 to 12);
	signal bg_color : l_px_t;
	signal lcd_clear : std_logic;
	signal lcd_con : std_logic;
	signal pic_addr, l_addr : l_addr_t;
	signal pic_data_o : l_px_t;
	signal lcd_count : integer range 0 to 4;
	signal text_color : l_px_arr_t(1 to 12);
	signal draw_done : std_logic;
	signal flash_mod, flash : std_logic;
	signal test_speed : integer range 1 to 3;
	signal move_pixel : integer range 8 to 24;
	--lcd text color
	constant all_blue : l_px_arr_t(1 to 12) := (blue, blue, blue, blue, blue, blue, blue, blue, blue, blue, blue, blue);
	--tts
	signal max_len : integer := 50;
	signal tts_ena, tts_busy, tts_done : std_logic;
	signal tts_data : u8_arr_t(0 to max_len - 1);
	signal tts_len : integer range 0 to max_len;
	signal tts_count : integer range 0 to 10;

	constant tts_start : u8_arr_t(0 to 16) := (x"b1", x"d2", x"b0", x"ca", x"bb", x"79", x"ad", x"b5", x"4c", x"43", x"44", x"b4", x"fa", x"b8", x"d5", x"be", x"b9");
	--啟動語音LCD測試器
	constant tts2_1 : u8_arr_t(0 to 9) := (x"78", x"79", x"ae", x"79", x"bc", x"d0", x"c2", x"49", x"a9", x"f3");
	--xy座標點於
	constant tts2_2 : u8_arr_t(0 to 17) := (x"b9", x"b3", x"af", x"c0", x"c2", x"49", x"b6", x"7d", x"a9", x"6c", x"b6", x"69", x"a6", x"e6", x"b4", x"fa", x"b8", x"d5");
	--像素點開始進行測試
	constant tts3_mod : u8_arr_t(0 to 9) := (x"a4", x"75", x"a7", x"40", x"bc", x"d2", x"a6", x"a1", x"ac", x"b0");
	-- 工作模式為
	constant tts3_speed : u8_arr_t(0 to 5) := (x"b3", x"74", x"ab", x"d7", x"ac", x"b0");
	-- 速度為
	constant tts3_color : u8_arr_t(0 to 13) := (x"af", x"c5", x"a5", x"42", x"b2", x"be", x"b0", x"ca", x"a4", x"e8", x"b6", x"f4", x"ac", x"b0");
	-- 級且移動方塊為
	constant tts_pause2 : u8_arr_t(0 to 7) := (x"b4", x"fa", x"b8", x"d5", x"bc", x"c8", x"b0", x"b1");
	-- 測試暫停
	constant tts_continue : u8_arr_t(0 to 7) := (x"b4", x"fa", x"b8", x"d5", x"c4", x"7e", x"c4", x"f2");
	-- 測試繼續
	constant tts_normal : u8_arr_t(0 to 3) := (x"a4", x"40", x"af", x"eb");
	-- 一般
	constant tts_flash : u8_arr_t(0 to 3) := (x"b0", x"7b", x"c3", x"7b");
	-- 閃爍
	constant tts_green : u8_arr_t(0 to 3) := (x"ba", x"f1", x"a6", x"e2");
	-- 綠色
	constant tts_red : u8_arr_t(0 to 3) := (x"ac", x"f5", x"a6", x"e2");
	-- 紅色
	constant tts_blue : u8_arr_t(0 to 3) := (x"c2", x"c5", x"a6", x"e2");
	-- 藍色
	constant tts_pause1 : u8_arr_t(0 to 2) := (x"40", x"8f", x"00");
	--(語音即時暫停)
	constant tts_resume : u8_arr_t(0 to 2) := (x"40", x"8f", x"01");
	--(語音即時取消暫停)

	--timer
	signal timer_ena : std_logic;
	signal timer_load, timer_msec : i32_t;
begin
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
			lcd_sclk         => lcd_sclk,
			lcd_mosi         => lcd_mosi,
			lcd_ss_n         => lcd_ss_n,
			lcd_dc           => lcd_dc,
			lcd_bl           => lcd_bl,
			lcd_rst_n        => lcd_rst_n,
			con              => lcd_con,
			pic_addr         => l_addr,
			pic_data         => pic_data_o
		);
	tts_inst : entity work.tts(arch)
		generic map(
			txt_len_max => 50
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
	edge_inst_tts_busy : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => tts_busy,
			rising  => open,
			falling => tts_done
		);
	timer_inst : entity work.timer(arch)
		port map(
			clk   => clk,
			rst_n => rst_n,
			ena   => timer_ena,
			load  => timer_load,
			msec  => timer_msec
		);
	clk_1_inst : entity work.clk(arch)
		generic map(
			freq => 1
		)
		port map(
			clk_in  => clk,
			rst_n   => rst_n,
			clk_out => clk_1
		);
	clk_2_inst : entity work.clk(arch)
		generic map(
			freq => 2
		)
		port map(
			clk_in  => clk,
			rst_n   => rst_n,
			clk_out => clk_2
		);
	clk_3_inst : entity work.clk(arch)
		generic map(
			freq => 3
		)
		port map(
			clk_in  => clk,
			rst_n   => rst_n,
			clk_out => clk_3
		);
	clk_10_inst : entity work.clk(arch)
		generic map(
			freq => 5
		)
		port map(
			clk_in  => clk,
			rst_n   => rst_n,
			clk_out => clk_5
		);
	edge_clk1_inst : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => clk_1,
			rising  => clk_1hz,
			falling => open
		);
	edge_clk2_inst : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => clk_2,
			rising  => clk_2hz,
			falling => open
		);
	edge_clk3_inst : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => clk_3,
			rising  => clk_3hz,
			falling => open
		);
	edge_clk10_inst : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => clk_5,
			rising  => clk_5hz,
			falling => open
		);
	edge_lcd_draw_inst : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => font_busy,
			rising  => open,
			falling => draw_done
		);
	process (clk, rst_n)
	begin
		if rst_n = '0' then
			color_change_flag <= '0';
			x_change_flag <= '0';
			y_change_flag <= '0';
			xy_set_mod <= '0';
			x_set_flag <= '0';
			y_set_flag <= '0';
			mix_mod <= '0';
			flash <= '0';
			lcd_count <= 0;
			lcd_clear <= '1';
			bg_color <= white;
			pic_col <= green;
			tts_ena <= '0';
			seg_data <= "        ";
			seg_dot <= "00000000";
			x <= 1;
			y <= 1;
			l_x <= 1;
			l_y <= 1;
			l_x_m1 <= 1;
			l_y_m1 <= 1;
			l_x_m2 <= 1;
			l_y_m2 <= 1;
			col_setup <= '0';
			timer_ena <= '0';
			flash_mod <= '0';
			test_speed <= 1;
			move_pixel <= 8;
			mode_t <= res;
			seg_mod_t <= xy_set;
			stop_flag <= '0';
		elsif rising_edge(clk) then
			if key_pressed = '1' and sw(6 to 7) = "00" and key_data = 0 then -- mod00
				tts_count <= 9;
				l_x <= l_x_m1;
				l_y <= l_y_m1;
				stop_flag <= '0';
				mix_mod <= '0';
				col_setup <= '0';
				lcd_clear <= '1';
				mode_t <= mod0;
			elsif key_pressed = '1' and sw(6 to 7) = "01" then -- mod01
				if key_data = 2 then
					if x_set_flag = '0' then
						l_x_m2 <= l_x_m1;
					elsif y_set_flag = '0' then
						l_y_m2 <= l_y_m1;
					elsif x_set_flag = '1' then
						x_set_flag <= '0';
					elsif y_set_flag = '1' then
						y_set_flag <= '0';
					end if;
					x_change_flag <= '0';
					y_change_flag <= '0';
					mode_t <= mod1;
					xy_set_mod <= '0';
					seg_mod_t <= xy_set;
				elsif key_data = 3 then -- color set
					if col_setup = '0' then
						col_mod <= 0;
					elsif col_setup = '1' then
						col_setup <= '0';
					end if;
					color_change_flag <= '0';
					mode_t <= mod1;
					seg_mod_t <= col_set;
				end if;
			elsif key_pressed = '1' and sw(6 to 7) = "10" and key_data = 0 then -- mod10
				mix_mod <= '0';
				col_setup <= '0';
				lcd_count <= 0;
				mode_t <= mod2;
				tts_count <= 9;
			elsif key_pressed = '1' and sw(6 to 7) = "11" and key_data = 0 then -- mod11
				stop_flag <= '0';
				tts_count <= 0;
				lcd_con <= '0';
				lcd_clear <= '1';
				mode_t <= mod0;
				mix_mod <= '1';
			end if;
			case mode_t is
				when res => --rst_n
					stop_flag <= '0';
					tts_ena <= '0';
					mix_mod <= '0';
					flash <= '0';
					test_speed <= 1;
					move_pixel <= 8;
					flash_mod <= '0';
					lcd_count <= 0;
					col_mod <= 0;
					lcd_con <= '0';
					lcd_clear <= '1';
					seg_data <= "        ";
					seg_dot <= "00000000";
				when mod0 =>
					if key_pressed = '1' and key_data = 1 then -- start/pause
						stop_flag <= not stop_flag;
					end if;
					case test_speed is -- speed mux
						when 1 => test_clk <= clk_1hz;
						when 2 => test_clk <= clk_2hz;
						when 3 => test_clk <= clk_3hz;
						when others => null;
					end case;
					seg_data <= "        ";
					seg_dot <= "00000000";
					lcd_clear <= '1';
					lcd_con <= '1';
					pic_data_o <= to_data(l_paste(l_addr, white, pic_col, (l_y, l_x), 16, 16));
					pic_addr <= to_addr(l_paste(l_addr, white, pic_col, (l_y, l_x), 16, 16));
					if flash_mod = '1' and clk_5hz = '1' then --flash
						lcd_con <= '0';
						if col_mod = 0 then
							if pic_col = green then
								pic_col <= white;
							else
								pic_col <= green;
							end if;
						elsif col_mod = 1 then
							if pic_col = red then
								pic_col <= white;
							else
								pic_col <= red;
							end if;
						elsif col_mod = 2 then
							if pic_col = blue then
								pic_col <= white;
							else
								pic_col <= blue;
							end if;
						end if;
					end if;
					if stop_flag = '0' and test_clk = '1' then -- move
						lcd_con <= '0';
						if l_x < 113 then
							l_x <= l_x + move_pixel;
						else
							l_x <= 1;
							if l_y < 145 then
								l_y <= l_y + move_pixel;
							else
								l_y <= 1;
							end if;
						end if;
					end if;
					-- if mix_mod = '1' then
					case tts_count is
						when 0 =>
							tts_ena <= '1';
							tts_data(0 to 16) <= tts_start;
							tts_len <= 17;
							if tts_busy = '1' then
								tts_ena <= '0';
								tts_count <= 1;
							end if;
						when 1 =>
							if tts_done = '1' then
								tts_ena <= '1';
								tts_data(0 to 39) <= tts2_1 & to_big(l_x_m1) & to_big(l_y_m1) & tts2_2;
								tts_len <= 40;
								tts_count <= 2;
							end if;
						when 2 =>
							if tts_busy = '1' then
								tts_ena <= '0';
								tts_count <= 3;
							end if;
						when 3 =>
							if tts_done = '1' then
								tts_ena <= '1';
								if flash_mod = '0' then
									if col_mod = 0 then
										tts_data(0 to 43) <= tts3_mod & tts_normal & tts3_speed & to_big(test_speed) & tts3_color & tts_green;
									elsif col_mod = 1 then
										tts_data(0 to 43) <= tts3_mod & tts_normal & tts3_speed & to_big(test_speed) & tts3_color & tts_red;
									elsif col_mod = 2 then
										tts_data(0 to 43) <= tts3_mod & tts_normal & tts3_speed & to_big(test_speed) & tts3_color & tts_blue;
									end if;
								else
									if col_mod = 0 then
										tts_data(0 to 43) <= tts3_mod & tts_flash & tts3_speed & to_big(test_speed) & tts3_color & tts_green;
									elsif col_mod = 1 then
										tts_data(0 to 43) <= tts3_mod & tts_flash & tts3_speed & to_big(test_speed) & tts3_color & tts_red;
									elsif col_mod = 2 then
										tts_data(0 to 43) <= tts3_mod & tts_flash & tts3_speed & to_big(test_speed) & tts3_color & tts_blue;
									end if;
								end if;
								tts_len <= 44;
								tts_count <= 4;
							elsif stop_flag = '1' then
								tts_count <= 4;
							end if;
						when 4 =>
							if tts_busy = '1' then
								tts_ena <= '0';
								if stop_flag = '0' then
									tts_count <= 3;
								else
									tts_count <= 5;
									tts_len <= 3;
									tts_data(0 to 2) <= tts_pause1; --(即時暫停)
								end if;
							end if;
						when 5 =>
							tts_ena <= '1';

							tts_count <= 6;
						when 6 =>
							if tts_busy = '1' then
								tts_ena <= '0';
								tts_count <= 7;
							end if;
						when 7 =>
							if tts_done = '1' then
								tts_ena <= '1';
								tts_data(0 to 7) <= tts_pause2;
								tts_len <= 8;
								tts_count <= 8;
							end if;
						when 8 =>
							if tts_busy = '1' then
								tts_ena <= '0';
							end if;
							if key_pressed = '1' and key_data = 1 then
								tts_count <= 9;
							end if;
						when 9 =>
							tts_data(0 to 7) <= tts_continue;
							tts_len <= 8;
							tts_ena <= '1';
							tts_count <= 10;
						when 10 =>
							if tts_busy = '1' then
								tts_ena <= '0';
								tts_count <= 3;
							end if;
						when others =>
					end case;
					-- end if;
				when mod1 =>
					lcd_con <= '0';
					lcd_clear <= '1';
					case seg_mod_t is
						when xy_set =>
							seg_dot <= "10001000";
							seg_data <= "x" & to_string(l_x_m2, l_x_m2'high, 10, 3) & "y" & to_string(l_y_m2, l_y_m2'high, 10, 3);
							if xy_set_mod = '0' then
								if key_pressed = '1' and key_data = 4 then
									x_change_flag <= '1';
									if l_x_m2 /= 113 then
										l_x_m2 <= l_x_m2 + 8;
									else
										l_x_m2 <= 1;
									end if;
								elsif key_pressed = '1' and key_data = 5 then
									x_change_flag <= '1';
									if l_x_m2 /= 1 then
										l_x_m2 <= l_x_m2 - 8;
									else
										l_x_m2 <= 113;
									end if;
								elsif key_pressed = '1' and key_data = 6 then
									x_set_flag <= '1';
									xy_set_mod <= '1';
									l_x_m1 <= l_x_m2;
								end if;
							else
								if key_pressed = '1' and key_data = 4 then
									y_change_flag <= '1';
									if l_y_m2 /= 145 then
										l_y_m2 <= l_y_m2 + 8;
									else
										l_y_m2 <= 1;
									end if;
								elsif key_pressed = '1' and key_data = 5 then
									y_change_flag <= '1';
									if l_y_m2 /= 1 then
										l_y_m2 <= l_y_m2 - 8;
									else
										l_y_m2 <= 145;
									end if;
								elsif key_pressed = '1' and key_data = 6 then
									y_set_flag <= '1';
									xy_set_mod <= '0';
									l_y_m1 <= l_y_m2;
								end if;
							end if;
							if key_pressed = '1' and key_data = 3 then
								seg_mod_t <= col_set;
								if x_change_flag = '0' then
									x_set_flag <= '1';
								elsif y_change_flag = '0' then
									y_set_flag <= '1';
								end if;
							end if;
						when col_set =>
							seg_dot <= "00010000";
							if col_mod = 0 then
								seg_data <= "CoL GrEE";
							elsif col_mod = 1 then
								seg_data <= "CoL  rED";
							elsif col_mod = 2 then
								seg_data <= "CoL BLUE";
							end if;
							if key_pressed = '1' and key_data = 5 then
								color_change_flag <= '1';
								if col_mod /= 2 then
									col_mod <= col_mod + 1;
								else
									col_mod <= 0;
								end if;
							elsif key_pressed = '1' and key_data = 6 then
								col_setup <= '1';
								if col_mod = 0 then
									pic_col <= green;
								elsif col_mod = 1 then
									pic_col <= red;
								elsif col_mod = 2 then
									pic_col <= blue;
								end if;
							elsif key_pressed = '1' and key_data = 2 then
								if color_change_flag = '0' then
									col_setup <= '1';
								end if;
							end if;
					end case;
				when mod2 =>
					seg_data <= "        ";
					seg_dot <= "00000000";
					if key_pressed = '1' and key_data = 7 then -- Flash/Normal mod set
						flash_mod <= not flash_mod;
					elsif key_pressed = '1' and key_data = 8 then -- speed set
						if test_speed /= 3 then
							test_speed <= test_speed + 1;
						else
							test_speed <= 1;
						end if;
					elsif key_pressed = '1' and key_data = 9 then -- move_pixel set
						if move_pixel /= 24 then
							move_pixel <= move_pixel + 8;
						else
							move_pixel <= 8;
						end if;
					elsif key_pressed = '1' and key_data = 6 then -- back mod00
						mode_t <= mod0;
					end if;
					case lcd_count is
						when 0 => -- white
							x <= 4;
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
									text_color <= all_blue;
									y <= 10;
									lcd_count <= 1;
								end if;
							end if;
						when 1 =>
							lcd_clear <= '0';
							if y = 10 then
								text_data <= " LCD TESTER ";
								font_start <= '1';
							end if;
							if draw_done = '1' then
								text_color <= all_blue;
								font_start <= '0';
								y <= 40;
								lcd_count <= 2;
							end if;
						when 2 =>
							if y = 40 and flash_mod = '0' then
								text_data <= "Modes:Normal";
								font_start <= '1';
							elsif y = 40 and flash_mod = '1' then
								text_data <= "Modes:Flash ";
								font_start <= '1';
							end if;
							if draw_done = '1' then
								text_color <= all_blue;
								font_start <= '0';
								y <= 70;
								lcd_count <= 3;
							end if;
						when 3 =>
							if y = 70 then
								text_data <= "Speed:" & to_string(test_speed, test_speed'high, 10, 1) & "     ";
								font_start <= '1';
							end if;
							if draw_done = '1' then
								text_color <= all_blue;
								font_start <= '0';
								y <= 100;
								lcd_count <= 4;
							end if;
						when 4 =>
							if y = 100 then
								text_data <= "Moving:" & to_string(move_pixel, move_pixel'high, 10, 2) & "   ";
								font_start <= '1';
							end if;
							if draw_done = '1' then
								text_color <= all_blue;
								font_start <= '0';
								y <= 10;
								lcd_count <= 1;
							end if;
					end case;
				when tts_res =>
					tts_ena <= '1';
					tts_data(0 to 16) <= tts_start;
					tts_len <= 28;
					if tts_done = '1' then
						tts_ena <= '0';
						tts_count <= 0;
						mode_t <= mod0;
					end if;
				when lcd_stop =>
					if key_pressed = '1' and key_data = 1 then -- move pause
						mode_t <= mod0;
					end if;
				when others =>
			end case;
		end if;
	end process;
end arch;

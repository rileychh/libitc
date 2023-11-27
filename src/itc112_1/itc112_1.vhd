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
		tts_rst_n        : out std_logic;
		-- mot
		mot_ch  : out u2r_t;
		mot_ena : out std_logic
	);
end itc112_1;

architecture arch of itc112_1 is
	signal clk_1, clk_1hz, clk_2, clk_2hz, clk_3, clk_3hz, clk_5, clk_5hz, test_clk : std_logic;
	signal mix_mod : std_logic;

	signal stop_flag : std_logic; -- when '1' => stop
	signal reset_flag : std_logic; -- when '1' => tts reset
	signal x_set_flag, y_set_flag : std_logic; -- when '1' => set sucess
	signal xy_set_mod : std_logic; -- when '0' => set x, when '1' => set y
	signal x_change_flag, y_change_flag, color_change_flag : std_logic; -- when '1' => x or y or color is changed
	signal shape_flag : std_logic;

	type mode is (res, idle, mod0, mod1, mod2, mod3);
	signal mode_t : mode;
	type seg_mod is (xy_set, col_set);
	signal seg_mod_t : seg_mod;
	type tts_mode_t is (idle, send, stop);
	signal tts_mode : tts_mode_t;
	signal tts_stop_mode : integer range 0 to 2;
	signal key_stop_flag : std_logic;
	signal moving_flag : std_logic;

	--seg
	signal seg_data : string(1 to 8);
	signal seg_dot : u8r_t;
	--key
	signal pressed_i, key_pressed : std_logic;
	signal key_data : i4_t;
	--lcd
	signal x, l_x, l_x_m1, l_x_m2 : integer range -127 to 128;
	signal y, l_y, l_y_m1, l_y_m2 : integer range -159 to 160;
	signal col_setup : std_logic; -- set success
	signal col_mod, col_mod_m, col_mod_m_lcd : integer range 0 to 2; -- 0 = green, 1 = red, 2 = blue
	signal pic_col : l_px_t; -- can set pic color 
	signal font_start, font_busy : std_logic;
	signal text_data : string(1 to 12);
	signal bg_color, pic_data_o : l_px_t;
	signal lcd_clear : std_logic;
	signal lcd_con : std_logic;
	signal pic_addr_tri, l_addr, shape_1_addr, shape_2_addr : l_addr_t;
	signal tri_data, shape_1_data, shape_2_data : l_px_t;
	signal tri_data_o, shape_1_data_o, shape_2_data_o : std_logic_vector(23 downto 0);
	signal lcd_count : integer range 0 to 4;
	signal text_color : l_px_arr_t(1 to 12);
	signal draw_done : std_logic;
	signal flash_mod, flash : std_logic;
	signal test_speed : integer range 1 to 3;
	signal move_pixel : integer range 0 to 50;
	signal moving : integer range 0 to 50;
	--lcd text color
	constant all_blue : l_px_arr_t(1 to 12) := (blue, blue, blue, blue, blue, blue, blue, blue, blue, blue, blue, blue);
	--tts
	signal stop_speak : std_logic;
	signal max_len : integer := 50;
	signal tts_ena, tts_busy, tts_done : std_logic;
	signal tts_data : u8_arr_t(0 to max_len - 1);
	signal tts_len : integer range 0 to max_len;
	signal tts_count : integer range 0 to 12;

	constant tts_start : u8_arr_t(0 to 16) := (x"b1", x"d2", x"b0", x"ca", x"bb", x"79", x"ad", x"b5", x"4c", x"43", x"44", x"b4", x"fa", x"b8", x"d5", x"be", x"b9");
	--啟動語音LCD測試器
	
constant tts2_1 : u8_arr_t(0 to 29) := (
	x"78", x"79", x"ae", x"79", x"bc", x"d0", x"c2", x"49", x"a9", x"f3", x"33", x"33", x"be", x"f3", x"af", x"c0",
	x"c2", x"49", x"b6", x"7d", x"a9", x"6c", x"b6", x"69", x"a6", x"e6", x"b4", x"fa", x"b8", x"d5"
);
-- "xy座標點於33橡素點開始進行測試"
constant tts3 : u8_arr_t(0 to 41) := (
        x"a4", x"75", x"a7", x"40", x"bc", x"d2", x"a6", x"a1", x"ac", x"b0", x"a4", x"40", x"af", x"eb", x"ad", x"49",
        x"b4", x"ba", x"c3", x"43", x"a6", x"e2", x"ac", x"b0", x"c2", x"c5", x"a6", x"e2", x"b4", x"fa", x"b8", x"d5",
        x"b9", x"cf", x"b6", x"f4", x"ac", x"b0", x"a4", x"e8", x"a7", x"ce"
);
-- "工作模式為一般背景顏色為藍色測試圖塊為方形", 42

	constant tts3_mod : u8_arr_t(0 to 9) := (x"a4", x"75", x"a7", x"40", x"bc", x"d2", x"a6", x"a1", x"ac", x"b0");
	-- 工作模式為
	constant tts3_speed : u8_arr_t(0 to 5) := (x"b3", x"74", x"ab", x"d7", x"ac", x"b0");
	-- 速度為
	constant tts3_color : u8_arr_t(0 to 13) := (x"af", x"c5", x"a5", x"42", x"b2", x"be", x"b0", x"ca", x"a4", x"e8", x"b6", x"f4", x"ac", x"b0");
	-- 級且移動方塊為
	constant tts_pause : u8_arr_t(0 to 7) := (x"b4", x"fa", x"b8", x"d5", x"bc", x"c8", x"b0", x"b1");
	-- 測試暫停
	constant tts_space : u8_arr_t(0 to 1) := (x"20", x"20");
	-- 空白
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
	-- constant tts_pause1 : u8_arr_t(0 to 2) := (x"40", x"8f", x"00");
	--(語音即時暫停)
	-- constant tts_resume : u8_arr_t(0 to 2) := (x"40", x"8f", x"01");
	--(語音即時取消暫停)

	--timer
	signal timer_ena : std_logic;
	signal timer_load, timer_msec : i32_t;

	signal dir : std_logic;
	signal speed : integer range 0 to 100;
begin
	mot_inst : entity work.mot(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			mot_ch  => mot_ch,
			mot_ena => mot_ena,
			dir     => dir,
			speed   => speed
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
			addr             => l_addr,
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
			pic_data         => pic_data_o
		);
	-- tts_inst : entity work.tts(arch)
	-- 	generic map(
	-- 		txt_len_max => 50
	-- 	)
	-- 	port map(
	-- 		clk       => clk,
	-- 		rst_n     => rst_n,
	-- 		tts_scl   => tts_scl,
	-- 		tts_sda   => tts_sda,
	-- 		tts_mo    => tts_mo,
	-- 		tts_rst_n => tts_rst_n,
	-- 		ena       => tts_ena,
	-- 		busy      => tts_busy,
	-- 		txt       => tts_data,
	-- 		txt_len   => tts_len
	-- 	);
	tts_stop_inst : entity work.tts_stop(arch)
		generic map(
			txt_len_max => 50
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
	tri_red_inst : entity work.tri_red7(syn)
		port map(
			address => std_logic_vector(to_unsigned(pic_addr_tri, 11)),
			clock   => clk,
			q       => tri_data_o
		);
	shape_1_inst : entity work.shape_1(syn)
		port map(
			address => std_logic_vector(to_unsigned(shape_1_addr, 11)),
			clock   => clk,
			q       => shape_1_data_o
		);
	shape_2_inst : entity work.shape_2(syn)
		port map(
			address => std_logic_vector(to_unsigned(shape_2_addr, 11)),
			clock   => clk,
			q       => shape_2_data_o
		);
	tri_data <= unsigned(tri_data_o);
	shape_1_data <= unsigned(shape_1_data_o);
	shape_2_data <= unsigned(shape_2_data_o);
	process (clk, rst_n)
	begin
		if rst_n = '0' then
			moving_flag <= '0';
			moving <= 8;
			shape_flag <= '0';
			key_stop_flag <= '0';
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
			pic_col <= white;
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
			move_pixel <= 16;
			mode_t <= res;
			seg_mod_t <= xy_set;
			stop_flag <= '0';
			tts_ena <= '1';
			tts_data(0 to 1) <= tts_space;
			tts_len <= 2;
		elsif rising_edge(clk) then
			if sw(6 to 7) = "00" and key_pressed = '1' and key_data = 12 then -- mod00
				l_x <= l_x_m1;
				l_y <= l_y_m1;
				stop_flag <= '0';
				mix_mod <= '0';
				lcd_clear <= '1';
				mode_t <= mod0;
				tts_mode <= stop;
				tts_ena <= '1';
				tts_data(0 to 1) <= tts_space;
				tts_len <= 2;
			elsif sw(6 to 7) = "01" then -- mod01
				lcd_con <= '0';
				lcd_clear <= '1';
				-- bg_color <= white;
				if key_data = 14 then
					if x_set_flag = '0' then
						l_x_m2 <= l_x_m1;
					elsif x_set_flag = '1' then
						x_set_flag <= '0';
					end if;
					if y_set_flag = '0' then
						l_y_m2 <= l_y_m1;
					elsif y_set_flag = '1' then
						y_set_flag <= '0';
					end if;
					x_change_flag <= '0';
					y_change_flag <= '0';
					mode_t <= mod1;
					xy_set_mod <= '0';
					seg_mod_t <= xy_set;
				elsif key_data = 15 then -- color set
					color_change_flag <= '0';
					mode_t <= mod1;
					seg_mod_t <= col_set;
				end if;
				tts_ena <= '1';
				tts_data(0 to 1) <= tts_space;
				tts_len <= 2;
			elsif sw(6 to 7) = "10" and key_pressed = '1' and key_data = 12 then -- mod10
				mix_mod <= '0';
				col_setup <= '0';
				lcd_count <= 0;
				mode_t <= mod2;
				tts_mode <= stop;
				tts_ena <= '1';
				tts_data(0 to 1) <= tts_space;
				tts_len <= 2;
			elsif sw(6 to 7) = "11" and key_pressed = '1' and key_data = 12 then -- mod11
				l_x <= l_x_m1;
				l_y <= l_y_m1;
				stop_flag <= '0';
				tts_count <= 0;
				lcd_con <= '0';
				lcd_clear <= '1';
				mode_t <= mod3;
				mix_mod <= '1';
				tts_mode <= idle;
				reset_flag <= '0';
				tts_ena <= '1';
				tts_data(0 to 1) <= tts_space;
				tts_len <= 2;
			end if;
			case mode_t is
				when res => --rst_n
					mix_mod <= '1';
					stop_flag <= '0';
					tts_ena <= '0';
					mix_mod <= '0';
					flash <= '0';
					test_speed <= 1;
					move_pixel <= 16;
					flash_mod <= '0';
					lcd_count <= 0;
					col_mod <= 0;
					lcd_con <= '0';
					lcd_clear <= '1';
					seg_data <= "        ";
					seg_dot <= "00000000";
					reset_flag <= '0';
				when idle =>
					lcd_clear <= '1';
					bg_color <= white;
					seg_data <= "        ";
					seg_dot <= "00000000";
				when mod0 =>
					tts_ena <= '0';
					if key_pressed = '1' and key_data = 13 then -- start/pause
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
					lcd_con <= '0';
					if flash_mod = '0' and sw(6 to 7) /= "01" then
						if shape_flag = '0' then
							bg_color <= to_data(l_paste(l_addr, pic_col, l_map(tri_data, white, pic_col), (l_y - 2, l_x - 5), 36, 32));
							pic_addr_tri <= to_addr(l_paste(l_addr, pic_col, l_map(tri_data, white, pic_col), (l_y - 2, l_x - 5), 36, 32));
						else
							bg_color <= to_data(l_paste(l_addr, pic_col, red, (l_y - 1, l_x - 1), 32, 32));
						end if;
					elsif flash_mod = '1' and sw(6 to 7) /= "01" then
						bg_color <= pic_col;
					elsif sw(6 to 7) = "01" then
						bg_color <= white;
						mode_t <= idle;
					end if;
					if stop_flag = '0' and clk_1hz = '1' and sw(6 to 7) /= "01" then
						flash_mod <= '0';
						if l_x + 32 < 128 then
							l_x <= l_x + move_pixel;
						else
							l_x <= 1;
							if l_y + 32 < 160 then
								l_y <= l_y + move_pixel;
							else
								l_y <= 1;
							end if;
						end if;
					elsif stop_flag = '1' and clk_2hz = '1' and sw(6 to 7) /= "01" then
						flash_mod <= not flash_mod;
					end if;
				when mod1 =>
					tts_ena <= '0';
					lcd_con <= '0';
					lcd_clear <= '1';
					case seg_mod_t is
						when xy_set =>
							seg_dot <= "10001000";
							seg_data <= "x" & to_string(l_x_m2, l_x_m2'high, 10, 3) & "y" & to_string(l_y_m2, l_y_m2'high, 10, 3);
							if xy_set_mod = '0' and x_set_flag = '0' then
								if key_pressed = '1' and key_data = 8 then
									x_change_flag <= '1';
									if l_x_m2 /= 128 then
										l_x_m2 <= l_x_m2 + 1;
									else
										l_x_m2 <= 1;
									end if;
								elsif key_pressed = '1' and key_data = 9 then
									x_change_flag <= '1';
									if l_x_m2 /= 1 then
										l_x_m2 <= l_x_m2 - 1;
									else
										l_x_m2 <= 128;
									end if;
								elsif key_pressed = '1' and key_data = 5 then
									-- x_set_flag <= '1';
									xy_set_mod <= '1';
									-- l_x_m1 <= l_x_m2;
								end if;
							elsif xy_set_mod = '1' and y_set_flag = '0' then
								if key_pressed = '1' and key_data = 8 then
									y_change_flag <= '1';
									if l_y_m2 /= 160 then
										l_y_m2 <= l_y_m2 + 1;
									else
										l_y_m2 <= 1;
									end if;
								elsif key_pressed = '1' and key_data = 9 then
									y_change_flag <= '1';
									if l_y_m2 /= 1 then
										l_y_m2 <= l_y_m2 - 1;
									else
										l_y_m2 <= 160;
									end if;
								elsif key_pressed = '1' and key_data = 5 then
									-- y_set_flag <= '1';
									xy_set_mod <= '0';
									-- l_y_m1 <= l_y_m2;
								end if;
							end if;
							if key_pressed = '1' and key_data = 10 then
								x_set_flag <= '1';
								y_set_flag <= '1';
								l_x_m1 <= l_x_m2;
								l_y_m1 <= l_y_m2;
							end if;
							-- if key_pressed = '1' and key_data = 3 then
							-- 	seg_mod_t <= col_set;
							-- 	if x_change_flag = '0' then
							-- 		x_set_flag <= '1';
							-- 	elsif y_change_flag = '0' then
							-- 		y_set_flag <= '1';
							-- 	end if;
							-- end if;
						when col_set =>
							seg_dot <= "00100000";
							if col_mod_m = 0 then
								seg_data <= "BGDWHITE";
							elsif col_mod_m = 1 then
								seg_data <= "BGD BLUE";
							elsif col_mod_m = 2 then
								seg_data <= "BGDBLACK";
							end if;
							if key_pressed = '1' and key_data = 9 then
								color_change_flag <= '1';
								if col_mod_m /= 2 then
									col_mod_m <= col_mod_m + 1;
								else
									col_mod_m <= 0;
								end if;
							elsif key_pressed = '1' and key_data = 10 then
								col_mod <= col_mod_m;
								col_setup <= '1';
							elsif key_pressed = '1' and key_data = 2 then
								col_setup <= '1';
								col_mod <= col_mod;
								col_mod_m <= col_mod;
							end if;
							if col_mod = 0 then
								pic_col <= white;
							elsif col_mod = 1 then
								pic_col <= blue;
							elsif col_mod = 2 then
								pic_col <= black;
							end if;
					end case;
				when mod2 =>
					tts_ena <= '0';
					seg_dot <= "10001000";
					seg_data <= "x" & to_string(l_x_m2, l_x_m2'high, 10, 3) & "y" & to_string(l_y_m2, l_y_m2'high, 10, 3);
					if key_pressed = '1' and key_data = 4 then
						shape_flag <= not shape_flag;
						lcd_count <= 0;
						lcd_clear <= '1';
					elsif key_pressed = '1' and key_data = 11 then
						moving_flag <= '1';
					elsif key_pressed = '1' and key_data = 10 then -- back mod00
						l_x <= l_x_m1;
						l_y <= l_y_m1;
						mode_t <= mod0;
					end if;
					if moving_flag = '1' then
						if key_pressed = '1' and key_data = 8 then
							move_pixel <= moving - 1;
							if moving /= 50 then
								moving <= moving + 1;
							else
								moving <= 1;
							end if;
						elsif key_pressed = '1' and key_data = 9 then
							move_pixel <= moving - 1;
							if moving /= 1 then
								moving <= moving - 1;
							else
								moving <= 50;
							end if;
						end if;
					else
						move_pixel <= moving - 1;
					end if;
					if shape_flag = '1' and sw(6 to 7) /= "01" then
						bg_color <= to_data(l_paste(l_addr, white, shape_1_data, (130, 5), 128, 15));
						shape_1_addr <= to_addr(l_paste(l_addr, white, shape_1_data, (130, 5), 128, 15));
					elsif shape_flag = '0' and sw(6 to 7) /= "01" then
						bg_color <= to_data(l_paste(l_addr, white, shape_2_data, (130, 5), 128, 15));
						shape_2_addr <= to_addr(l_paste(l_addr, white, shape_2_data, (130, 5), 128, 15));
					elsif sw(6 to 7) = "01" then
						bg_color <= white;
						mode_t <= idle;
					end if;
					case lcd_count is
						when 0 => -- white
							x <= 5;
							lcd_con <= '0';
							lcd_clear <= '1';
							if shape_flag = '1' then
								bg_color <= to_data(l_paste(l_addr, white, shape_1_data, (130, 5), 128, 15));
								shape_1_addr <= to_addr(l_paste(l_addr, white, shape_1_data, (130, 5), 128, 15));
							elsif shape_flag = '0' then
								bg_color <= to_data(l_paste(l_addr, white, shape_2_data, (130, 5), 128, 15));
								shape_2_addr <= to_addr(l_paste(l_addr, white, shape_2_data, (130, 5), 128, 15));
							end if;
							if draw_done = '1' then
								font_start <= '0';
								lcd_count <= 1;
							end if;
						when 1 =>
							x <= 5;
							y <= 10;
							lcd_clear <= '0';
							text_data <= " LCD TESTER ";
							font_start <= '1';
							if draw_done = '1' then
								text_color <= all_blue;
								font_start <= '0';
								lcd_count <= 2;
							end if;
						when 2 =>
							y <= 40;
							text_data <= "Modes:Normal";
							font_start <= '1';
							if draw_done = '1' then
								text_color <= all_blue;
								font_start <= '0';
								lcd_count <= 3;
							end if;
						when 3 =>
							y <= 70;
							text_data <= "Moving:" & to_string(moving, moving'high, 10, 2) & "   ";
							font_start <= '1';
							if draw_done = '1' then
								text_color <= all_blue;
								font_start <= '0';
								lcd_count <= 4;
							end if;
						when 4 =>
							y <= 100;
							if pic_col = white then
								text_data <= "BGD:WHITE   ";
							elsif pic_col = blue then
								text_data <= "BGD:BLUE    ";
							elsif pic_col = black then
								text_data <= "BGD:BLACK   ";
							end if;
							font_start <= '1';
							if draw_done = '1' then
								text_color <= all_blue;
								font_start <= '0';
								lcd_count <= 1;
							end if;
					end case;
				when mod3 =>
					seg_dot <= "10001000";
					seg_data <= "x" & to_string(l_x_m2, l_x_m2'high, 10, 3) & "y" & to_string(l_y_m2, l_y_m2'high, 10, 3);
					if key_pressed = '1' and key_data = 13 then -- start/pause
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
					lcd_con <= '0';
					if flash_mod = '0' and sw(6 to 7) /= "01" then
						bg_color <= to_data(l_paste(l_addr, pic_col, red, (l_y - 1, l_x - 1), 32, 32));
					elsif sw(6 to 7) = "01" then
						bg_color <= white;
						mode_t <= idle;
					end if;
					if stop_flag = '0' and clk_1hz = '1' and sw(6 to 7) /= "01" then
						flash_mod <= '0';
						if l_x + 32 < 128 then
							l_x <= l_x + move_pixel;
						else
							l_x <= 1;
							if l_y + 32 < 160 then
								l_y <= l_y + move_pixel;
							else
								l_y <= 1;
							end if;
						end if;
					else
						l_x <= l_x;
						l_y <= l_y;
					end if;
					case tts_mode is
						when idle =>
							if tts_busy = '0' then
								tts_ena <= '0';
								tts_mode <= send;
							end if;
						when send =>
							case tts_count is
								when 0 =>
									tts_data(0 to 16) <= tts_start;
									tts_len <= 17;
									tts_ena <= '1';
								when 1 =>
									tts_data(0 to 29) <= tts2_1;
									tts_len <= 30;
									tts_ena <= '1';
								when 2 =>
									tts_data(0 to 41) <= tts3;
									tts_len <= 42;
									tts_ena <= '1';
								when 3 =>
									tts_data(0 to 1) <= tts_instant_soft_reset;
									tts_len <= 2;
									reset_flag <= '1';
									tts_ena <= '1';
								when 4 =>
									tts_data(0 to 1) <= tts_instant_soft_reset;
									tts_len <= 2;
									tts_ena <= '1';
								when 5 =>
									tts_data(0 to 1) <= tts_space;
									tts_len <= 2;
									reset_flag <= '0';
									tts_ena <= '1';
								when 6 =>
									tts_data(0 to 7) <= tts_continue;
									tts_len <= 8;
									tts_ena <= '1';
								when 7 =>
									tts_data(0 to 7) <= tts_pause;
									tts_len <= 8;
									tts_ena <= '1';
								when 8 =>
									tts_data(0 to 1) <= tts_space;
									tts_len <= 2;
									tts_ena <= '1';
								when 9 =>
									tts_data(0 to 1) <= tts_space;
									tts_len <= 2;
									tts_ena <= '1';
								when 10 =>
									tts_data(0 to 1) <= tts_instant_soft_reset;
									tts_len <= 2;
									tts_ena <= '1';
								when 11 =>
									tts_data(0 to 1) <= tts_instant_soft_reset;
									tts_len <= 2;
									tts_ena <= '1';
								when 12 => 
									tts_data(0 to 1) <= tts_space;
									tts_len <= 2;
									tts_ena <= '1';
								when others =>
							end case;
							if tts_busy = '1' then
								tts_mode <= stop;
							end if;
						when stop =>
							if tts_count = 0 and stop_flag = '0' and reset_flag = '0' then -- tts1 end go to tts2
								tts_count <= 1;
							elsif tts_count = 1 and stop_flag = '0' and reset_flag = '0' then -- tts2 end go to tts3
								tts_count <= 2;
							elsif tts_count = 2 and stop_flag = '0' and reset_flag = '0' then -- repeat tts3
								tts_count <= 2;
							elsif tts_count = 2 and stop_flag = '1' and reset_flag = '0' then -- when stop_flag = '1' go to tts reset
								tts_count <= 3;
							elsif tts_count = 3 and stop_flag = '1' and reset_flag = '1' then -- reset done
								tts_count <= 4;
							elsif tts_count = 4 and stop_flag = '1' and reset_flag = '1' then -- blank file because tts reset bug
								tts_count <= 5;
							elsif tts_count = 5 and stop_flag = '1' and reset_flag = '0' then -- tts pause
								tts_count <= 7;
							elsif tts_count = 7 and stop_flag = '1' and reset_flag = '0' then -- back to blank file
								tts_count <= 8;
							elsif tts_count = 8 and stop_flag = '0' and reset_flag = '0' then -- when stop_flag = '0' go to tts reset
								tts_count <= 3;
							elsif tts_count = 3 and stop_flag = '0' and reset_flag = '1' then -- reset done
								tts_count <= 4;
							elsif tts_count = 4 and stop_flag = '0' and reset_flag = '1' then -- blank file because tts reset bug
								tts_count <= 5;
							elsif tts_count = 5 and stop_flag = '0' and reset_flag = '0' then -- tts continue
								tts_count <= 6;
							elsif tts_count = 6 and stop_flag = '0' and reset_flag = '0' then -- back to repeat tts3
								tts_count <= 2;
							elsif tts_count = 10 then
								tts_count <= 11;
							elsif tts_count = 11 then
								tts_count <= 12;
							elsif tts_count = 12 then
								tts_count <= 0;		
							end if;
							tts_ena <= '0';
							tts_mode <= idle;
					end case;
			end case;
		end if;
	end process;
end arch;

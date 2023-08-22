library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;


entity itc110_e1 is
	port (
		-- system
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
		-- dht
		dht_data : inout std_logic;
		-- tts
		tts_scl, tts_sda : inout std_logic;
		tts_mo           : in unsigned(2 downto 0);
		dbg_b : 		out 	u8r_t;
		tts_rst_n        : out std_logic
	);
end itc110_e1;

architecture arch of itc110_e1 is
constant max_len : integer := 100;
	-- "?????????? 20
-- tts_data(0 to 19) <= sys ;
-- tts_len <= 20;
constant set_vol :u8_arr_t(0 to 1) :=(x"86", x"f0");
constant day : i8_arr_t(1 to 12) := (31,28,31,30,31,30,31,31,30,31,30,31);
constant sys  : u8_arr_t(0 to 19) := (
	x"a8", x"74", x"b2", x"ce", x"b6", x"7d", x"be", x"f7", x"a9", x"f3", x"a6", x"7e", x"a4", x"eb", x"a4", x"e9",
	x"ac", x"50", x"b4", x"c1"
);

-- "??? 6
-- tts_data(0 to 5) <= time;
-- tts_len <= 6;
constant date : u8_arr_t(0 to 5) := (
	x"ae", x"c9", x"a4", x"c0", x"ac", x"ed"
);

-- "????, 6
-- tts_data(0 to 5) <= temp;
-- tts_len <= 6;
constant temp : u8_arr_t(0 to 5) := (
	x"b7", x"c5", x"ab", x"d7", x"ac", x"b0"
);

-- "6
-- tts_data(0 to 5) <= humd;
-- tts_len <= 6;
constant humd : u8_arr_t(0 to 5) := (
	x"c0", x"e3", x"ab", x"d7", x"ac", x"b0"
);

-- "??22
-- tts_data(0 to 21) <= num;
-- tts_len <= 22;
constant d_year : u8_arr_t(0 to 7) := (
        x"a4", x"47", x"b9", x"73", x"a4", x"47", x"a4", x"40"
);
type remainder_map_t is array(1 to 7) of string(1 to 4);
constant remainder_map : remainder_map_t := (
     "Mon.","Tue.","Wed.","Thu.","Fri.","Sat.","Sun."
);	
-- tts_len <= 4;
constant h : u8_arr_t(0 to 3) := (
        x"a5", x"bf", x"b1", x"60"
);

-- "", 4
-- tts_len <= 4;
constant g : u8_arr_t(0 to 3) := (
        x"b9", x"4c", x"b0", x"aa"
);
	type mode_t is (none,idle, TFT_lcd_test, test2, start, setup,test_all);
	type status_t is (rst,init,run);
	signal seg_status : status_t;
	signal sub_mode : integer range 0 to 4;
	type lcd_t is (setup, lcd_scan);
	signal lcd : lcd_t;
	signal mode : mode_t;
	signal bg_color, text_color : l_px_t;
	signal ena, wr_ena : std_logic;
	signal addr : l_addr_t;
	signal load, msec,blink : i32_t;
	signal seg_data : string(1 to 8);
	--key
	signal pressed, pressed_i : std_logic;
	signal key : i4_t;
	--seg 
	signal dot : u8_t;
	--lcd
	signal font_start : std_logic;
	signal font_busy : std_logic;
	signal draw_start, draw_done, lcd_clear : std_logic;
	signal x : integer range 0 to 127;
	signal y : integer range 0 to 158;
	signal data: string(1 to 12);
	signal lcd_count : integer range 0 to 9;
	signal set_tmp : integer range 0 to 40;
	signal set_hum : integer range 0 to 99;
	signal tmp : integer range 0 to 40 := 27;
	signal hum : integer range 0 to 99 := 75;
	signal hour : integer range 0 to 23 := 13;
	signal mins, secs : integer range 0 to 59 := 00;
	signal set_up_down : integer range -1 to 1;
	signal temp_int, hum_int : integer range 0 to 99;
	signal draw_color : integer range 0 to 7;
	signal clk_out, time_clk : std_logic;
	signal text_count : integer range 1 to 12;
	--tts
	signal tts_ena : std_logic;
	signal busy : std_logic;
	signal txt : u8_arr_t(0 to max_len - 1);
	signal len : integer range 0 to max_len;
	signal flag : integer range 0 to 3;
	signal status : integer range 0 to 10; 
	signal speak : integer range 0 to 10;
	signal done :boolean;
	signal year : integer range 2020 to 2023:=2021;
	signal days : integer range 1 to 31 :=24;
	signal month : integer range 1 to 12 :=11;
	signal presss_5 : std_logic;
	signal tts_start ,tts_done : std_logic;
	signal big_length : Integer range 0 to 99;
	signal latch ,dis,pause,resume: std_logic;
	signal tts_status : std_logic;
	signal remainder : integer range 1 to 7 :=1;
	signal tts_channel : u8_arr_t(0 to 1) := (tts_set_channel,x"07");
	signal set_time,pre_set_time,timer_ena : std_logic ;
begin
	done <= (pressed='1') and (key = 0);
	dbg_b <= seg_led;
	inst: block begin
		tts_inst: entity work.tts(arch)
			generic map (
				txt_len_max => max_len
			)
			port map (
				clk => clk,
				rst_n => rst_n,
				tts_scl => tts_scl,
				tts_sda => tts_sda,
				tts_mo => tts_mo,
				tts_rst_n => tts_rst_n,
				ena => tts_ena,
				busy => busy,
				txt => txt,
				txt_len => len
			);
		edge_inst : entity work.edge(arch)
			port map(
				clk     => clk,
				rst_n   => rst_n,
				sig_in  => pressed_i,
				rising  => pressed,
				falling => open
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
			--dsf
		clk_inst : entity work.clk(arch)
			generic map(
				freq => 1
			)
			port map(
				clk_in  => clk,
				rst_n   => rst_n,
				clk_out => clk_out
			);
		edge_inst1 : entity work.edge(arch)
			port map(
				clk     => clk,
				rst_n   => rst_n,
				sig_in  => font_busy,
				rising  => draw_start,
				falling => draw_done
			);
		time_clk_edge_inst : entity work.edge(arch)
			port map(
				clk     => clk,
				rst_n   => rst_n,
				sig_in  => clk_out,
				rising  => time_clk,
				falling => open
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
		lcd_draw : entity work.gen_font(arch)
			port map(
				clk        => clk,
				rst_n      => rst_n,
				x          => x,
				y          => y,
				text_size  => 1,
				addr 	   => addr,
				font_start => font_start,
				font_busy  => font_busy,
				data       => data,
				text_count => text_count,
				text_color => text_color,
				bg_color   => bg_color,
				clear      => lcd_clear,
				lcd_sclk   => lcd_sclk,
				lcd_mosi   => lcd_mosi,
				lcd_ss_n   => lcd_ss_n,
				lcd_dc     => lcd_dc,
				lcd_bl     => lcd_bl,
				lcd_rst_n  => lcd_rst_n

			);
		seg_inst : entity work.seg(arch)
			port map(
				clk     => clk,
				rst_n   => rst_n,
				seg_led => seg_led,
				seg_com => seg_com,
				data    => seg_data,
				dot     => dot
			);
		timer_inst : entity work.timer(arch)
			port map(
				clk   => clk,
				rst_n => rst_n,
				ena   => ena,
				load  => 0,
				msec  => msec
			);
		timer_inst2 : entity work.timer(arch)
			port map(
				clk   => clk,
				rst_n => rst_n,
				ena   => timer_ena,
				load  => 0,
				msec  => blink
			);
		edge3_inst: entity work.edge(arch)
			port map (
				clk => clk,
				rst_n => rst_n,
				sig_in => busy,
				rising => tts_start,
				falling => tts_done
			);
		edge4_inst: entity work.edge(arch)
			port map (
				clk => clk,
				rst_n => rst_n,
				sig_in => tts_status,
				rising => pause,
				falling =>resume
			);
	end block inst;

	process (clk, rst_n)
	begin
		if rst_n = '0' then
			mode <= none;
			ena <= '0';
			tts_ena <= '0';
			sub_mode <= 1;
			timer_ena <= '0';
			dot <= x"00";
			seg_data <= "00000000";
			bg_color <= white;
			lcd_clear <= '1';
			font_start <= '0';
			x <= 0;
			pre_set_time <= '0';
			y <= 0;
			tts_ena <= '0';
			set_tmp <= 27;
			set_hum <= 75;
			speak <= 1;
			latch <= '0';
			dis <= '0';
			set_time <= '1';
			status <= 0;
			sub_mode <= 0;
			tts_status <= '1';
		elsif rising_edge(clk) then
			if time_clk = '1'and tts_status = '0'then
				if secs = secs'high then
					secs <= 0;
					if mins = mins'high then
						mins <= 0;
						if hour = hour'high then
							hour <= 0;
							if days = day(month) then
								if(month = 12) then
									year <= year + 1;
									month <= 1;
								else
									month <= month + 1;
								end if;
								days <= 1;
							else
								days <= days +  1;
							end if;
							remainder <= (year + year/4 + year/400 - year/100 + (month + days - 1)) rem 7 + 3;
						else
							hour <= hour + 1;
						end if;
					else
						mins <= mins + 1;
					end if;
				else
					secs <= secs + 1;
				end if;
			end if;
			if done then
				lcd_clear <= '0';
				lcd_count <= 0;
				font_start <= '0';
				ena <= '0';
				case sw(6 to 7) is
					when "00" => 
						mode <= TFT_lcd_test;
						bg_color <= red;
						text_color <= green;
						if lcd_clear = '0' then
						lcd_clear <= '1';
						end if;
						dis <= '0';
					when "01" => 
						mode <= start;
						dis <= '0';
						sub_mode <= 1;

					when "10" => 
						bg_color <= white;
						ena <= '1';
						tts_status <= not tts_status;
						dis <= '1';
						tts_ena <= '0';
						lcd_clear <= '0';
						lcd_count <= 0;
						seg_status <= init;
						mode <= setup;
						sub_mode <= 1;
					when "11" =>  
						bg_color <= white;
						ena <= '1';
						tts_status <= not tts_status;
						dis <= '1';
						tts_ena <= '0';
						lcd_clear <= '0';
						lcd_count <= 0;
						mode <= test_all;
						status <= 0;
						seg_status <= init;
						sub_mode <= 0;
						end case;
			end if;
			case mode is
				when none => 
					null;
				when idle =>
					if bg_color = white then
						font_start <= '0';
						lcd_clear <= '0';
						mode <= test2;
					end if;
				when TFT_lcd_test =>
					ena <= '1';
					lcd_clear <= '0';
					if msec <=1000 then
						lcd_clear <= '1';
					elsif msec >= 1000 and bg_color = red then
						bg_color <= white;
						if font_busy = '0' then
							lcd_clear <= '1';
						else
							lcd_clear <= '0';
						end if;
					elsif bg_color = white and msec >= 2000 then
						ena <= '0';
						font_start <= '0';
						lcd_clear <= '0';
						text_color <= green;
						lcd_count <= 1;
						mode <= idle;
						y <= 40;
					end if;
				when test2 =>
					if ena = '0' then
						ena <= '1';
					end if;
					case lcd_count is
						when 1 =>
							if font_busy = '0' then
								font_start <= '1';
							end if;
							if y = 40 then
								data <= "Mon         ";
								if draw_done = '1' then
									y <= 20;
									font_start <= '0';
								end if;
							end if;
							if y = 20 then
								data <= " 1          ";
								if msec >= 2500 then
									lcd_count <= 2;
									font_start <= '0';
									y <= 20;
								end if;
							end if;
						when 2 =>
							if font_busy = '0' then
								font_start <= '1';
							end if;
							if y = 20 then
								data <= " 1  3       ";
								if draw_done = '1' then
									y <=0 ;
									font_start <= '0';
								end if;
							end if;
							if y = 0 then
								data <= "   Wed.     ";
								if msec >= 3000 then
									lcd_count <= 3;
									font_start <= '0';
									y <= 20;
								end if;
							end if;
						when 3 =>
							if font_busy = '0' then
								font_start <= '1';
							end if;
							if y = 20 then
								data <= " 1  3  5    ";
								if draw_done = '1' then
									y <= 40;
									font_start <= '0';
								end if;
							end if;
							if y = 40 then
								data <= "Mon.  Fri.  ";
								if msec >= 3500 then
									lcd_count <= 4;
									font_start <= '0';
									y <= 20;
								end if;
							end if;
						when 4 =>
							if font_busy = '0' then
								font_start <= '1';
							end if;
							if y = 20 then
								data <= " 1  3  5 7  ";
								if draw_done = '1' then
									y <= 0;
									font_start <= '0';
								end if;
							end if;
							if y = 0 then
								data <= "   Wed. Sun.";
								if msec >= 4000 then
									lcd_count <= 5;
									font_start <= '0';
									y <= 80;
								end if;
							end if;
						when 5 => ---second line
							if font_busy = '0' then
								font_start <= '1';
							end if;
							if y = 80 then
								data <= " 9          ";
								if draw_done = '1' then
									y <= 100;
									font_start <= '0';
								end if;
							end if;
							if y = 100 then
								data <= " :          ";
								if msec >= 4500 then
									lcd_count <= 6;
									font_start <= '0';
									y <= 60;
								end if;
							end if;
						when 6 =>
							if font_busy = '0' then
								font_start <= '1';
							end if;
							if y = 60 then
								data <= "   Tue.     ";
								if draw_done = '1' then
									y <= 80;
									font_start <= '0';
								end if;
							end if;
							if y = 80 then
								data <= " 9  2       ";
								if msec >= 5000 then
									lcd_count <= 7;
									font_start <= '0';
									y <= 80;
								end if;
							end if;
						when 7 =>
							if font_busy = '0' then
								font_start <= '1';
							end if;
							if y = 80 then 
								data <= " 9  2  4    ";
								if draw_done = '1' then
									y <= 100;
									font_start <= '0';
								end if;
							end if;
							if y = 100 then
								data <= " :    Thu.  ";
								if msec >= 5500 then
									lcd_count <= 8;
									font_start <= '0';
									y <= 80;
								end if;
							end if;
						when 8 =>
							if font_busy = '0' then
								font_start <= '1';
							end if;
							if y = 80 then
								data <= " 9  2  4  6 ";
								if draw_done = '1' then
									y <= 60;
									font_start <= '0';
								end if;
							end if;
							if y = 60 then
								data <= "   Tue. Sat.";
								if msec >=6000 then
									lcd_count <= 9;
									font_start <= '0';
									y <= 120;
								end if;
							end if;
						when 9 =>
							if font_busy = '0' then
								font_start <= '1';
							end if;
							if y = 120 then
								data <= " 8          ";
								if draw_done = '1' then
									y <= 140;
									font_start <= '0';
								end if;
							end if;
							if y = 140 then
								data <= "dC          ";
								if msec >= 6500 then
									y <= 120;
									mode <= none;
									lcd_clear <= '0';
									lcd_count <= 0;
									font_start <= '0';
									ena <= '0';
								end if;
							end if;
						when others =>
					end case;
				when start =>
						ena <= '1';
						dot <= b"01000000";
						if dis = '0' then
							if draw_done = '1'  then
								bg_color <= red;
								lcd_clear <= '0';
							else 
								lcd_clear <= '1';
							end if;
						end if;
						if msec > 500 then
							ena <= '0';
							mode <= setup;
							seg_status <= init;
						end if;
				when setup =>
					case seg_status is
						when rst => 
						when init => 
							pre_set_time <= set_time;
							set_tmp <= tmp;
							set_hum <= hum;
							seg_status <= run;
						when run => 
							case sw(0 to 3) is
								when x"0" =>
									seg_data <= "0000ModE";
									seg_status <= init;
								when  x"1" =>
								if sub_mode = 0 then
									txt(0 to 27) <= set_vol & tts_channel  & to_big(hour) & date(0 to 1) & to_big(mins) & date(2 to 3) & to_big(secs) & date(4 to 5);
									len <= 28;
									tts_ena <= '1';
									if tts_done= '1' then
										tts_ena <= '0';
									end if;
								end if;
								if key = 3 and pressed ='1' then
									pre_set_time <= not pre_set_time;
								end if;
								if key = 6 and pressed = '1' then
									set_time <= pre_set_time;
									seg_status <= init;
								end if;
								if pre_set_time = '1' then
									seg_data <= "0124ModE";
									else
									seg_data <= "0112ModE";
									end if;
								when "0010" =>
									if sub_mode = 0 then
										if temp_int > tmp then
										txt(0 to 19) <=set_vol & tts_channel  & temp(0 to 5) & to_big(temp_int) & g;
										else
										txt(0 to 19) <=set_vol & tts_channel  & temp(0 to 5) & to_big(temp_int) & h;
										end if;
										len <= 20;
										tts_ena <= '1';
										if tts_done= '1' then
											tts_ena <= '0';
										end if;
									end if;
									if pressed ='1' then
										case key is
											when 4 => 
											set_tmp <= set_tmp - 1;
											when 5 => 
											set_tmp <= set_tmp + 1;
											when 6 => 
											tmp <=  set_tmp;
											when others => 
										end case;
									end if;
									seg_data <= "02"&to_string(set_tmp, set_tmp'high, 10, 2) & "ModE";
								when "0100" =>
								if sub_mode = 0 then
									if hum_int > hum then
										txt(0 to 19) <=set_vol & tts_channel  & humd(0 to 5) & to_big(hum_int) & g;
									else
										txt(0 to 19) <=set_vol & tts_channel  & humd(0 to 5) & to_big(hum_int) & h;
									end if;
									len <= 20;
									tts_ena <= '1';
									if tts_done= '1' then
										tts_ena <= '0';
									end if;
								end if;
									if pressed ='1' then
										case key is
											when 4 => 
											set_hum <= set_hum - 1;
											when 5 => 
											set_hum <= set_hum + 1;
											when 6 => 
											hum <=  set_hum;
											when others => 
										end case;
									end if;
									seg_data <="02"& to_string(set_hum, set_hum'high, 10, 2) & "ModE";
								when others => null;
							end case;
					end case;
				when test_all => 
					case status is
						when 0 =>  
							bg_color <= white;
							lcd_clear <= '1';
							if draw_done = '1' then
								lcd_clear <= '0';
								tts_ena <= '0';
								status <= 1;
							end if;
						when 1 =>
								tts_ena <= '1';
								txt(0 to 65) <= tts_channel & set_vol  & sys(0 to 9) &
												to_big(1) & to_big(1) & to_big(0) & to_big(year rem 10) & sys(10 to 11) &
												to_big(month) & sys(12 to 13) &
												to_big(days) & sys(14 to 15) &
												sys(16 to 19) & to_big(remainder) ;
								len <= 66;
									sub_mode <= 0;
									mode <= setup;
						when others =>
						
						end case;
				when others =>
					null;
			end case;

				-- case  speak is 
				-- 	when 2 => 
				-- 		txt(0 to 27) <= set_vol & tts_channel  & to_big(hour) & date(0 to 1) & to_big(mins) & date(2 to 3) & to_big(secs) & date(4 to 5);
				-- 		len <= 28;
				-- 		tts_ena <= '1';
				-- 		if tts_done= '1' then
				-- 			tts_ena <= '0';
				-- 		end if;
				-- 	when 3 => 
				-- 		txt(0 to 15) <=set_vol & tts_channel  & temp(0 to 5) & to_big(temp_int);
				-- 		len <= 16;
				-- 		tts_ena <= '1';
				-- 		if tts_done= '1' then
				-- 			tts_ena <= '0';
				-- 		end if;
						
				-- 	when 4 => 
				-- 		txt(0 to 15) <=set_vol & tts_channel  & humd(0 to 5) & to_big(hum_int);
				-- 		len <= 16;
				-- 		tts_ena <= '1';
				-- 		if tts_done= '1' then
				-- 			tts_ena <= '0';
				-- 		end if;
				-- 	when others => 
				-- 		null;			
				-- end case;		
			if blink > 1000 then
				timer_ena <= '0';
			end if;
			if dis = '1' and tts_status = '0' then
				case lcd_count is
					when 0 =>
						if draw_done = '1'  then
							lcd_clear <= '0';
						else 
							lcd_clear <= '1';
						end if;
						if msec > 500 then
							ena <= '0';
							lcd_count <= 1;
						end if;
					when 1 =>
						data <= "110" & to_string(month,month'high,10,2)& to_string(days,days'high,10,2) & "Wed. ";
						y <= 0;
						x <= 0;
						if font_busy = '0' then
							font_start <= '1';
						else
							font_start <= '1';
						end if;
						if draw_done = '1' then
							lcd_count <= 2;
							font_start <= '0';
						end if;
					when 2 =>
						y <= 40;
						x <= 0;
						if set_time = '1' then
							data <= "  " & to_string(hour, hour'high, 10, 2) & ":" & to_string(mins, mins'high, 10, 2) & ":" & to_string(secs, secs'high, 10, 2) & "  ";
						else
							data <= "  " & to_string(hour - 12, hour'high, 10, 2) & ":" & to_string(mins, mins'high, 10, 2) & ":" & to_string(secs, secs'high, 10, 2) & "  ";	
						end if;
						font_start <= '1';
						if draw_done = '1' then
							lcd_count <= 3;
							font_start <= '0';
						end if;
					when 3 =>
						y <= 100;
						x <= 0;
						
						data <= "  " & to_string(temp_int, temp_int'high, 10, 2) & "dC " & to_string(hum_int, hum_int'high, 10, 2) & '%' & "  ";
						font_start <= '1';

						if blink <= 500 then
							timer_ena <= '1';
							if text_count = 8 and hum_int >= hum then
								text_color <= white;
							elsif text_count = 1 and temp_int >= tmp then
								text_color <= white;
							elsif text_count = 7 and text_color = white then
								text_color <= green;
							end if;
						elsif blink >= 500 then
							if text_count = 8 and hum_int >= hum then
								text_color <= blue;
							elsif text_count = 1 and temp_int >= tmp then
								text_color <= blue;
							elsif text_count = 7 and text_color = blue then
								text_color <= green;
							end if;
						end if;
						if draw_done = '1' then
							lcd_count <= 4;
							text_color <= green;
							font_start <= '0';
						end if;
					when 4 => 
						y <= 120;
						x <= 0;
						if set_time = '1' then
							data <= "        24  ";
						else
							data <= "        12  ";	
						end if;
						font_start <= '1';
						if draw_done = '1' then
							lcd_count <= 1;
							font_start <= '0';
						end if;
						when others =>
							null;
				end case;
			end if;
		END IF;
	end process;
end arch;

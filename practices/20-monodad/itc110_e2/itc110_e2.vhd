library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;

entity itc110_e2 is
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
		--led
		rgb                 : out std_logic_vector(0 to 2);
		led_g, led_r, led_y : out std_logic;
		--dot
		dot_red, dot_green, dot_com : out u8r_t;
		--buzzer
		buz : out std_logic;
		--uart
		uart_rx : in std_logic;  -- receive pin
		uart_tx : out std_logic; -- transmit pin
		dbg_b   : out u8r_t

	);
end itc110_e2;
architecture arch of itc110_e2 is
	constant feed_dot : u8r_arr_t(0 to 7) := (x"42", x"42", x"42", x"42", x"E7", x"A7", x"A7", x"00");
	constant match : u8r_arr_t(0 to 7) := (x"18", x"3C", x"7E", x"FF", x"FF", x"FF", x"66", x"00");
	type feed_t is (init, first, second, compare);
	signal feed_branch : feed_t;
	type mode_t is (init, idle, feed, tacit, play, sport);
	type pre_mode is (rst, init, run, back);
	signal sport_branch : pre_mode;
	signal match_b : pre_mode;

	type led_t is (g, r, b);
	signal led : led_t;
	signal mode : mode_t;
	signal ena, wr_ena : std_logic;
	signal addr : l_addr_t;
	signal load, msec : i32_t;
	signal data : string(1 to 12);
	signal seg_data : string(1 to 8);
	signal inter_rst : std_logic;
	--4*4 key
	signal pressed_i, pressed : std_logic;
	signal key : i4_t;
	--seg 
	signal dot : u8_t;
	--8*8 dot led 
	signal data_g, data_r : u8r_arr_t(0 to 7);
	signal dot_x, dot_y : integer range 0 to 7;
	signal done : boolean;
	signal play_happy : integer range -50 to 150;
	--uart
	constant txt_len_max : integer := 32;
	signal pass_str : string(1 to 4);
	signal tx_ena, tx_busy, rx_busy, rx_err : std_logic;
	signal tx_data, rx_data : u8_t := x"00";
	signal pass : u8_arr_t(0 to 3);
	signal pass_str_temp : string(1 to 4);
	type keypad_t is array(0 to 9) of integer;
	signal keypad : character;
	signal count : integer range 0 to 50;
	signal tx_len, rx_len : integer range 1 to 4;
	signal rx_start, rx_done : std_logic;
	signal stop_buz : std_logic;
	signal font_start, draw_done : std_logic;
	signal font_busy, lcd_clean : std_logic;
	signal x, y : integer range 0 to 159;
begin

	edge_inst : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => pressed_i,
			rising  => pressed,
			falling => open
		);
	edge1_inst : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => font_busy,
			rising  => open,
			falling => draw_done
		);
	lcd_draw : entity work.gen_font(arch)
		port map(
			clk        => clk,
			rst_n      => rst_n,
			x          => x,			
			y          => y,		
			font_start => font_start,	
			font_busy  => font_busy,	
			text_size  => 1,			
			data       => data,			
			text_color => black,		
			addr       => addr,			
			bg_color   => white,		
			clear      => lcd_clean,	
			lcd_sclk   => lcd_sclk,		
			lcd_mosi   => lcd_mosi,		
			lcd_ss_n   => lcd_ss_n,		
			lcd_dc     => lcd_dc,		
			lcd_bl     => lcd_bl,		
			lcd_rst_n  => lcd_rst_n		

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
	key_inst : entity work.key(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			key_row => key_row,
			key_col => key_col,
			pressed => pressed_i,
			key     => key
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
	edge_inst1 : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => rx_busy,
			rising  => rx_start,
			falling => rx_done
		);

	inter_rst <= '0' when (key = 3) and (pressed = '1')else
		'1';
	dbg_b <= seg_led;
	done <= (pressed = '1') and (key = 15);
	keypad <=
		'1' when (pressed = '1') and (key = 0) else
		'2' when (pressed = '1') and (key = 1) else
		'3' when (pressed = '1') and (key = 2) else
		'4' when (pressed = '1') and (key = 4) else
		'5' when (pressed = '1') and (key = 5) else
		'6' when (pressed = '1') and (key = 6) else
		'7' when (pressed = '1') and (key = 8) else
		'8' when (pressed = '1') and (key = 9) else
		'9' when (pressed = '1') and (key = 10);
	process (clk, rst_n, inter_rst)
	begin
		if rst_n = '0' or inter_rst = '0' then
			ena <= '0';
			led <= g;
			led_g <= '0';
			led_r <= '0';
			seg_data <= "        ";
			dot_x <= 0;
			tx_ena <= '0';
			lcd_clean <= '0';
			dot_y <= 7;
			play_happy <= 20;
			buz <= '0';
			count <= 0;
			pass_str <= "    ";
			font_start <= '1';
			feed_branch <= init;
			mode <= init;
			pass <= (others => x"00");
		elsif rising_edge(clk) then

			if pressed = '1' then
				case key is
					when 13 =>
						seg_data <= "        ";
					when others =>
						null;
				end case;
			end if;
			case mode is
				when init =>
					lcd_clean <= '1';
					seg_data <= "        ";
					font_start <= '1';
					led_g <= '0';
					led_r <= '0';
					if ena = '0' then
						ena <= '1';
					end if;
					if dot_x = dot_x'high then
						dot_x <= 0;
						if dot_y = dot_y'high then
							dot_y <= 0;
						else
							dot_y <= dot_y + 1;
						end if;
					else
						dot_x <= dot_x + 1;
					end if;
					data_g(dot_y)(dot_x) <= '1';
					data_r(dot_y)(dot_x) <= '1';
					if msec <= 3000 then
						if msec rem 500 = 0 then
							case led is
								when g =>
									rgb <= b"100";
									led <= r;
								when r =>
									rgb <= b"010";
									led <= b;
								when b =>
									rgb <= b"001";
									led <= g;
								when others =>
									led <= g;
							end case;
						end if;
					else
						ena <= '0';
						rgb <= b"000";
						mode <= idle;
					end if;

				when idle =>
					match_b <= init;

					lcd_clean <= '1';
					seg_data <= "        ";
					font_start <= '1';
					led_g <= '0';
					led_r <= '0';
					-- if ena = '0' then
					-- 	ena <= '1';
					-- end if;
					-- if msec <= 3000 then
					-- 	if msec rem 500 = 0 then
					-- 		case led is
					-- 			when g =>
					-- 				rgb <= b"100";
					-- 				led <= r;
					-- 			when r =>
					-- 				rgb <= b"010";
					-- 				led <= b;
					-- 			when b =>
					-- 				rgb <= b"001";
					-- 				led <= g;
					-- 			when others =>
					-- 				led <= g;
					-- 		end case;
					-- 	end if;
					-- end if;
					case sw is
						when x"80" =>
							seg_data <= "    FEEd";
						when x"c0" =>
							seg_data <= "    MACH";
						when x"E0" =>
							seg_data <= "    WALK";
						when others =>
					end case;
					if done then
						case sw is
							when x"80" =>
								seg_data <= "        ";
								feed_branch <= init;
								mode <= feed;
								lcd_clean <= '0';
								dot_x <= 0;
								dot_y <= 0;
								ena <= '0';
							when x"c0" =>
								seg_data <= "        ";
								mode <= tacit;
								ena <= '0';
							when x"40" =>
								seg_data <= "        ";
								mode <= play;
								ena <= '0';
							when x"E0" =>
								mode <= sport;
								sport_branch <= init;
								seg_data <= "        ";
								ena <= '0';
							when others =>
						end case;
					end if;
				when feed =>
					-- if rx_done = '1' then
					-- 	if to_integer(rx_data) = 13 then
					-- 		x <= 0;
					-- 		y <= 0;
					-- 		font_start <= '1';
					-- 		data <= "  " & to_string(to_integer(pass(0)) - 48, 8, 10, 1) & " " & character'val(to_integer(pass(1))) & " " & character'val(to_integer(pass(2))) & " " & character'val(to_integer(pass(3))) & "   ";
					-- 		count <= 0;
					-- 	else
					-- 		font_start <= '0';
					-- 		pass(count) <= rx_data;
					-- 		count <= count + 1;
					-- 	end if;
					-- end if;
					if pressed = '1' then
						if key <= 11 and key /= 7 then
							pass_str <= pass_str(2 to 4) & keypad;
							font_start <= '0';
						end if;
					end if;
					case feed_branch is
						when init =>
							lcd_clean <= '1';
							if draw_done = '1' then
								pass_str <= "    ";
								data_r <= feed_dot;
								feed_branch <= first;
								data_g <= feed_dot;
								font_start <= '0';
							end if;
						when first =>
							x <= 0;
							y <= 0;
							data <= " " & pass_str(1) & "  " & pass_str(2) & "  " & pass_str(3) & "  " & pass_str(4) & " ";
							if draw_done = '1' then
								feed_branch <= second;
								pass_str_temp <= pass_str;
								pass_str <= "    ";
								font_start <= '0';

							end if;
							if done then
								font_start <= '1';
							end if;
						when second =>
							x <= 0;
							y <= 20;
							data <= " " & pass_str(1) & "  " & pass_str(2) & "  " & pass_str(3) & "  " & pass_str(4) & " ";
							if draw_done = '1' then
								feed_branch <= compare;
								font_start <= '0';
							end if;
							if done then
								font_start <= '1';
							end if;
						when compare =>
							x <= 30;
							y <= 80;
							if (pass_str) <= (pass_str_temp) then
								if font_start = '0' then
									font_start <= '1';
								else
									font_start <= '0';
								end if;
								data_g <= feed_dot;
								data_r <= (others => (others => '0'));
								data <= "OK          ";
							else
								led_g <= '1';
								if font_start = '0' then
									font_start <= '1';
								else
									font_start <= '0';
								end if;
								data_r <= feed_dot;
								data_g <= (others => (others => '0'));
								data <= "FAIL        ";
								-- 	led_r <= '1';
								-- 	if ena = '0' then
								-- 		buz <= '1';
								-- 		ena <= '1';
								-- 	elsif msec >= 1000 then
								-- 		buz <= '0';
								-- 	end if;
								-- end if
							end if;
							if done then
								data_g <= (others => (others => '1'));
								data_r <= (others => (others => '0'));
								ena <= '0';
								lcd_clean <= '0';
								mode <= idle;
							end if;
					end case;
				when tacit =>
					case match_b is
						when rst =>

						when init =>
							data_r <= match;
							data_g <= match;
							match_b <= run;
							-- pass(0) <= x"00";
							-- pass(1) <= x"00";
							-- pass_str <= "    ";
							-- pass(2) <= x"00";
						when run =>
							seg_data <= to_string(to_integer(pass(0)) - 48, 8, 10, 1) & character'val(to_integer(pass(1))) & character'val(to_integer(pass(2))) & character'val(to_integer(pass(3))) & pass_str;
							if rx_done = '1' then
								if to_integer(rx_data) = 13 then
									tx_ena <= '0';
									count <= 0;
								else
									tx_ena <= '0';
									pass(count) <= rx_data;
									count <= count + 1;
								end if;
							end if;

							if pressed = '1' then
								if key = 15 then
									if seg_data(1 to 4) = pass_str then
										led_g <= '1';
										tx_data <= to_unsigned(0, 8);
										tx_ena <= '1';
										data_g <= match;
										data_r <= (others => (others => '0'));
										match_b <= back;
									else
										tx_ena <= '1';
										match_b <= back;
										data_r <= match;
										data_g <= (others => (others => '0'));
										tx_data <= to_unsigned(1, 8);
									end if;
								end if;

								if key <= 11 and key /= 7 then
									pass_str <= pass_str(2 to 4) & keypad;
								end if;
							end if;
						when back =>
							if (tx_busy = '0') then
								tx_ena <= '0';
								if done then
									data_g <= (others => (others => '1'));
									data_r <= (others => (others => '0'));
									mode <= idle;
								end if;
							end if;
					end case;
				when play =>
					seg_data <= to_string(play_happy, play_happy'high, 10, 4) & "    ";
					if pressed = '1' and key = 7 then
						play_happy <= play_happy + 20;
					end if;
					if pressed = '1' and key = 11 then
						if play_happy <= 40 then
							play_happy <= 0;
							ena <= '0';
							buz <= '1';
						else
							play_happy <= play_happy - 40;
						end if;
					end if;
					if play_happy >= 100 then
						play_happy <= 100;
						led_g <= '1';
						led_r <= '0';
					end if;
					if play_happy <= 0 then
						led_g <= '0';
						led_r <= '1';
						if ena = '0' then
							ena <= '1';
						elsif msec >= 1000 then
							buz <= '0';
						end if;
					end if;
					if done then
						ena <= '0';
						buz <= '0';
						mode <= idle;
					end if;
				when sport =>
					case sport_branch is
						when rst =>
						when init =>
							data_r <= (others => (others => '0'));
							data_g <= (others => (others => '0'));
							sport_branch <= run;
							data_g(7)(0) <= '1';
							dot_y <= 7;
							dot_x <= 0;
						when run =>
							data_g(dot_y)(dot_x) <= '1';
							if pressed = '1' then
								data_g <= (others => (others => '0'));
								ena <= '1';
								buz <= '1';
								case key is
									when 1 =>
										dot_y <= dot_y + 1;
										data_g(dot_y - 1)(dot_x) <= '0';

									when 4 =>
										dot_x <= dot_x - 1;
										data_g(dot_y)(dot_x + 1) <= '0';

									when 6 =>
										dot_x <= dot_x + 1;
										data_g(dot_y)(dot_x - 1) <= '0';

									when 9 =>
										dot_y <= dot_y - 1;
										data_g(dot_y + 1)(dot_x) <= '0';

									when others =>
								end case;
							end if;
							if msec >= 250 then
								ena <= '0';
								buz <= '0';
							end if;
							if (dot_y = 5 and dot_x = 2) then
								data_r(5)(2) <= '0';
							else
								data_g(5)(2) <= '1';
								data_r(5)(2) <= '1';
							end if;
							if done then
								data_g <= (others => (others => '1'));
								data_r <= (others => (others => '0'));
								mode <= idle;
								buz <= '0';
							end if;
						when others =>
							null;
					end case;
			end case;
		end if;
	end process;
end arch;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;
entity itc109_1 is
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
		tts_rst_n        : out std_logic
	);
end itc109_1;
architecture arch of itc109_1 is
	--LCD
	signal font_busy, draw_start, draw_done, font_start, lcd_clear, ena : std_logic;
	signal text_count : integer range 0 to 9;
	signal data : string(1 to 13);
	signal bg_color, text_color : l_px_t;
	signal x, y : integer range 0 to 159;
	signal addr : l_addr_t;

	-- timer
	signal load, msec : i32_t;
	--seg
	signal seg_data : string(1 to 8);
	signal dot : u8_t;

	--key
	signal key : i4_t;
	signal busy, tts_ena, pressed, pressed_i : std_logic;
	signal txt : u8_arr_t(0 to 100 - 1);
	signal len : integer range 0 to 100;
	signal tts_start, tts_done : std_logic;
	signal temp_int, hum_int : integer range 0 to 99;
	-- idle
	type mode_t is (lcd, tts, tsl, test_all);
	signal mode : mode_t;
	type status_t is (rst, init, run);
	signal status : status_t;
	type lcd_status_t is (blink, countdown);
	signal lcd_status : lcd_status_t;
begin
	ip : block begin
		tts_inst : entity work.tts(arch)
			generic map(
				txt_len_max => 100
			)
			port map(
				clk       => clk,
				rst_n     => rst_n,
				tts_scl   => tts_scl,
				tts_sda   => tts_sda,
				tts_mo    => tts_mo,
				tts_rst_n => tts_rst_n,
				ena       => tts_ena,
				busy      => busy,
				txt       => txt,
				txt_len   => len
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
		edge_inst1 : entity work.edge(arch)
			port map(
				clk     => clk,
				rst_n   => rst_n,
				sig_in  => font_busy,
				rising  => draw_start,
				falling => draw_done
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
				addr       => addr,
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
		timer_inst : entity work.timer(arch)
			port map(
				clk   => clk,
				rst_n => rst_n,
				ena   => ena,
				load  => 0,
				msec  => msec
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
	end block ip;
	process (clk, rst_n)
	begin
		if rst_n = '0' then
			lcd_clear <= '0';

		elsif rising_edge(clk) then
			if key = 3 and pressed = '1' then
				status <= init;
				case sw(0 to 1) is
					when b"00" =>
						mode <= lcd;
					when b"01" =>
						mode <= tts;
					when b"10" =>
						mode <= tsl;
					when b"11" =>
						mode <= test_all;
					when others =>
				end case;
			end if;
			case mode is
				when lcd =>
					case status is
						when rst =>
						when init =>
							bg_color <= white;
							lcd_clear <= '1';
							status <= run;
							ena <= '0';
							lcd_status <= blink;
						when run =>
							case lcd_status is
								when blink =>
									if ena = '0' then
										ena <= '1';
										lcd_clear <= '1';
									end if;
									case msec / 500 is
										when 1 | 3 =>
											bg_color <= white;
											lcd_clear <= '1';
										when 2 | 4 =>
											bg_color <= black;
											lcd_clear <= '1';
										when 5 =>
											lcd_status <= countdown;
											ena <= '0';
										when others =>
											lcd_clear <= '0';

									end case;
									if addr = 128 * 80 then
										if bg_color = white then
											bg_color <= black;
										else
											bg_color <= white;
										end if;
									elsif draw_done = '1' then
										lcd_clear <= '0';
									end if;
								when countdown =>
							end case;
					end case;
				when tts =>
					case status is
						when rst =>
						when init =>
						when run =>
					end case;
				when tsl =>
					case status is
						when rst =>
						when init =>
						when run =>
					end case;
				when test_all =>
					case status is
						when rst =>
						when init =>
						when run =>
					end case;
			end case;
		end if;
	end process;
end arch; -- arch

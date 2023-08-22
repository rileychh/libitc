library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;
entity Topic is
	port (
		clk, rst_n : in std_logic;

		-- sw
		sw : in u8r_t;

		--seg
		seg_led, seg_com : out u8r_t;

		-- dht
		dht_data : inout std_logic;

		-- tsl
		tsl_scl, tsl_sda : inout std_logic;

		-- key
		key_row : in u4r_t;
		key_col : out u4r_t;

		rgb : out std_logic_vector(0 to 2);
		-- tts
		tts_scl, tts_sda : inout std_logic;
		tts_mo           : in unsigned (2 downto 0);
		dbg_b            : out u8r_t;
		tts_rst_n        : out std_logic;

		--uart
		uart_rx : in std_logic;  -- receive pin
		uart_tx : out std_logic; -- transmit pin

		-- lcd
		lcd_sclk, lcd_mosi, lcd_ss_n, lcd_dc, lcd_bl, lcd_rst_n : out std_logic
	);
end Topic;

architecture arch of Topic is
	------------------------------------------------------------------signal
	--seg
	signal seg_data : string(1 to 8) := (others => ' ');
	signal dot : u8r_t := (others => '0');
	--key
	signal pressed, pressed_i : std_logic;
	signal key : i4_t;
	signal keypad : character;
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
	type mode_t is (idle, setup);
	signal mode : mode_t;
	type tts_t is (idle, send, stop);
	signal tts : tts_t;
	----tsl
	signal lux : i16_t;
	--uart
	signal tx_data, rx_data : u8_t := x"00";
	signal rx_start, rx_done : std_logic;
	signal tx_ena, tx_busy, rx_busy, rx_err : std_logic;

	signal pass : u8r_t;--rx's data
	signal pass_str : string(1 to 4);--software pass
	signal count : integer range 0 to 50;

	--lcd
	signal lcd_count : integer range 0 to 10;

	constant air : u8_arr_t(0 to 7) := (x"aa", x"c5", x"ae", x"f0", x"ab", x"7e", x"bd", x"e8");
	constant good : u8_arr_t(0 to 3) := (x"a8", x"7d", x"a6", x"6e");
	constant bad : u8_arr_t(0 to 1) := (x"ae", x"74");
	constant danger : u8_arr_t(0 to 3) := (x"a6", x"4d", x"c0", x"49");

	constant temp : u8_arr_t(0 to 5) := (x"b7", x"c5", x"ab", x"d7", x"ac", x"b0");
	constant humd : u8_arr_t(0 to 5) := (x"c0", x"e3", x"ab", x"d7", x"ac", x"b0");
	constant C : u8_arr_t(0 to 1) := (x"ab", x"d7");

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
	tsl_inst : entity work.tsl(arch)
		port map(
			tsl_scl => tsl_scl,
			tsl_sda => tsl_sda,
			clk     => clk,
			rst_n   => rst_n,
			lux     => lux
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
			ena   => time_ena,
			load  => load,
			msec  => msec
		);

	edge_inst : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => pressed_i,
			rising  => pressed,
			falling => open
		);
	edge_inst_draw_done : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => font_busy,
			rising  => draw_start,
			falling => draw_done
		);
	edge_inst2 : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => clk_1hz,
			rising  => time_clk,
			falling => open
		);
	edge_inst3 : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => tts_busy,
			rising  => open,
			falling => tts_done
		);
	edge_inst_uart : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => rx_busy,
			rising  => rx_start,
			falling => rx_done
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
			txt       => txt,
			txt_len   => len
		);
	------------------------------seg
	seg_inst : entity work.seg(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			seg_led => seg_led,
			seg_com => seg_com,
			data    => seg_data,
			dot     => dot
		);
	------------------------------uart
	uart_inst : entity work.uart(arch)
		generic map(
			baud => 9600
		)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			uart_rx => uart_rx, --腳位
			uart_tx => uart_tx, --腳位
			tx_ena  => tx_ena,  --enable '1' 動作
			tx_busy => tx_busy, --tx資料傳送時tx_busy='1'
			tx_data => tx_data, --硬體要傳送的資料 
			rx_busy => rx_busy, --rx資料傳送時rx_busy='1'
			rx_err  => rx_err,  --檢測錯誤
			rx_data => rx_data  --由軟體接收到的資料 
		);

	---------------------------------------end packages
	process (clk, rst_n)
	begin
		if rst_n = '0' then
			lcd_clear <= '1';
			rgb <= "000";
			mode <= setup;
		elsif rising_edge(clk) then
			case mode is
				when setup =>
					lcd_clear <= '1';
					tts <= idle;
					lcd_count <= 0;
					x <= 0;
					y <= 0;
					bg_color <= white;
					font_start <= '0';
					text_size <= 1;
					text_color <= black;
					tts_ena <= '0';
					mode <= idle;
				when idle =>
					if rx_done = '1' then --接收軟體資料
						if to_integer(rx_data) = 13 then
							tx_ena <= '0';
						else
							tx_ena <= '0';
							pass <= rx_data;
						end if;
					end if;
					lcd_clear <= '0';
					case tts is
						when idle =>
							if pressed = '1' and key = 1 then
								tts <= send;
							end if;
						when send =>
							tts_ena <= '1';
							case to_integer(pass) is
								when 48 to 50 =>
									txt(0 to 47) <= temp & to_big(temp_int) & C & tts_delay & x"00" & x"00" & x"01" & x"f4" & humd & to_big(hum_int) & tts_delay & x"00" & x"00" & x"01" & x"f4" & air & good;
									len <= 48;
								when 51 to 52 =>
									txt(0 to 45) <= temp & to_big(temp_int) & C & tts_delay & x"00" & x"00" & x"01" & x"f4" & humd & to_big(hum_int) & tts_delay & x"00" & x"00" & x"01" & x"f4" & air & bad;
									len <= 46;
								when 53 to 54 =>
									txt(0 to 47) <= temp & to_big(temp_int) & C & tts_delay & x"00" & x"00" & x"01" & x"f4" & humd & to_big(hum_int) & tts_delay & x"00" & x"00" & x"01" & x"f4" & air & danger;
									len <= 48;
								when others =>
									txt(0 to 47) <= temp & to_big(temp_int) & C & tts_delay & x"00" & x"00" & x"01" & x"f4" & humd & to_big(hum_int) & tts_delay & x"00" & x"00" & x"01" & x"f4" & air & danger;
									len <= 48;
							end case;

							if tts_busy = '1' then
								tts_ena <= '0';
								tts <= stop;
							end if;
						when stop =>
							if tts_busy = '0' then
								tts <= idle;
							end if;
						when others =>
					end case;
					case lcd_count is --lcd_count(LCD)
						when 0 =>
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
									lcd_count <= 1;
									y <= 0;
								end if;
							end if;
						when 1 =>
							y <= 20;
							data <= " Temp:" & to_string(temp_int, temp_int'high, 10, 2) & "dC  ";
							font_start <= '1';
							if draw_done = '1' then
								font_start <= '0';
								lcd_count <= 2;
							end if;
						when 2 =>
							y <= 40;
							data <= " Hum:" & to_string(hum_int, hum_int'high, 10, 2) & "%    ";
							font_start <= '1';
							if draw_done = '1' then
								font_start <= '0';
								lcd_count <= 3;
							end if;
						when 3 =>
							y <= 60;
							data <= " Light:" & to_string(lux, lux'high, 10, 2) & "lx ";
							font_start <= '1';
							if draw_done = '1' then
								font_start <= '0';
								lcd_count <= 4;
							end if;
						when 4 =>
							y <= 80;
							case to_integer(pass) is
								when 49 to 50 =>
									data <= " air:good   ";
									rgb <= "010";
								when 51 to 52 =>
									data <= " air:bad    ";
									rgb <= "001";
								when 53 to 54 =>
									rgb <= "100";
									data <= " air:danger ";
								when others =>
									rgb <= "100";
									data <= " air:danger ";
							end case;
							font_start <= '1';
							if draw_done = '1' then
								font_start <= '0';
								lcd_count <= 1;
							end if;
						when others => null;
					end case;
				when others => null;
			end case;
		end if;
	end process;
end architecture;

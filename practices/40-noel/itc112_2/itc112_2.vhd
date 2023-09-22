library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;

entity itc112_2 is
	port (
		-- system
		clk   : in std_logic;
		rst_n : in std_logic;
		-- key
		key_row : in u4r_t;
		key_col : out u4r_t;
		-- sw
		sw : in u8r_t;
		-- 8x8 dot
		dot_red, dot_green, dot_com : out u8r_t;
		-- lcd
		lcd_sclk, lcd_mosi, lcd_ss_n, lcd_dc, lcd_bl, lcd_rst_n : out std_logic;
		-- seg
		seg_led, seg_com : out u8r_t;
		-- led
		led_g, led_r, led_y : out std_logic;
		-- rgb
		rgb : out std_logic_vector(0 to 2);
		--buzzer
		buz : out std_logic;
		-- mot
		mot_ch  : out u2r_t;
		mot_ena : out std_logic;
		-- uart
		uart_rx : in std_logic;  -- receive pin
		uart_tx : out std_logic; -- transmit pin
		dbg_b   : out u8r_t
	);
end itc112_2;

architecture arch of itc112_2 is
	-- system
	signal inter_rst : std_logic;
	signal count : integer range 0 to 50;
	signal pass : u8_arr_t(0 to 3);
	-- key
	signal pressed, key_pressed : std_logic;
	signal key_data : i4_t;
	-- dot
	signal data_r, data_g : u8r_arr_t(0 to 7);
	-- lcd
	signal l_x : integer range -127 to 127;
	signal l_y : integer range -159 to 159;
	signal font_start, font_busy, font_done : std_logic;
	signal text_data : string(1 to 12);
	signal text_color : l_px_arr_t(1 to 12);
	signal lcd_clear : std_logic;
	signal bg_color : l_px_t;
	signal lcd_con : std_logic;
	signal pic_addr : l_addr_t;
	signal pic_data : l_px_t;
	-- seg
	signal seg_data : string(1 to 8);
	signal seg_dot : u8r_t;
	-- rgb
	signal rgb_color : l_px_t;
	-- mot
	signal mot_dir : std_logic;
	signal mot_speed : integer range 0 to 100;
	-- uart
	signal tx_data, rx_data : u8_t := x"00";
	signal rx_start, rx_done : std_logic;
	signal tx_ena, tx_busy, rx_busy, rx_err : std_logic;
begin
	key_inst : entity work.key(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			key_row => key_row,
			key_col => key_col,
			pressed => pressed,
			key     => key_data
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
	lcd_mix_inst : entity work.lcd_mix(arch)
		port map(
			clk              => clk,
			rst_n            => rst_n,
			x                => l_x,
			y                => l_y,
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
	-- rgb_inst : entity work.rgb(arch)
	-- 	port map(
	-- 		clk   => clk,
	-- 		rst_n => rst_n,
	-- 		rgb   => rgb,
	-- 		color => rgb_color
	-- 	);
	mot_inst : entity work.mot(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			mot_ch  => mot_ch,
			mot_ena => mot_ena,
			dir     => mot_dir,
			speed   => mot_speed
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
	edge_key_pressed_inst : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => pressed,
			rising  => key_pressed,
			falling => open
		);
	edge_lcd_done_inst : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => font_busy,
			rising  => open,
			falling => font_done
		);
	edge_uart_rx_inst : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => rx_busy,
			rising  => rx_start,
			falling => rx_done
		);

	inter_rst <= '0' when (key_data = 3) and (key_pressed = '1') else '1';
	process (clk, rst_n)
	begin
		if rst_n = '0' or inter_rst = '0' then
			seg_data <= "        ";
			seg_dot <= "00000000";
			bg_color <= white;
			font_start <= '0';
			lcd_clear <= '1';
			rgb <= "100";
			tx_ena <= '0';
		elsif rising_edge(clk) then
			if rx_done = '1' then --接收軟體資料
				if to_integer(rx_data) = 13 then
					tx_ena <= '0';
					count <= 0;
					-- lcd_count <= 0;
					-- exchange <= chack;
				else
					tx_ena <= '0';
					pass(count) <= rx_data;
					count <= count + 1;
				end if;
			end if;
			seg_data <= "    " & to_string(to_integer(pass(0)) - 48, 9, 10, 1) & to_string(to_integer(pass(1)) - 48, 9, 10, 1) & to_string(to_integer(pass(2)) - 48, 9, 10, 1) & to_string(to_integer(pass(3)) - 48, 9, 10, 1);
		end if;
	end process;

end arch;

--!pp on
--!inc const_pkg.vhd

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;
use work.itc109_e2_const.all;

entity itc109_e2 is
	port (
		-- sys
		clk, rst_n : in std_logic;
		-- key
		key_row : in u4r_t;
		key_col : out u4r_t;
		-- sw
		sw : in u8r_t;
		-- dot
		dot_red, dot_green, dot_com : out u8r_t;
		-- seg
		seg_led, seg_com : out u8r_t;
		-- lcd
		lcd_sclk, lcd_mosi, lcd_ss_n, lcd_dc, lcd_bl, lcd_rst_n : out std_logic;
		-- led
		led_r, led_g, led_y : out std_logic;
		-- rgb
		rgb : out std_logic_vector(0 to 2);
		-- buz
		buz : out std_logic;
		-- uart
		uart_rx : in std_logic;  -- receive pin
		uart_tx : out std_logic; -- transmit pin
		-- debug
		dbg_a, dbg_b : out u8r_t
	);
end itc109_e2;

architecture arch of itc109_e2 is

	signal pressed, key_on_press : std_logic;
	signal key : i4_t;

	signal sw_i, sw_rising, sw_falling : u8r_t;

	signal dot_r, dot_g : u8r_arr_t(0 to 7);

	signal seg_data : string(1 to 8) := (others => ' ');
	signal seg_dot : u8r_t;

	signal l_bl : integer range 0 to 100;
	signal l_ena : std_logic;
	signal l_addr : l_addr_t;
	signal l_data : l_px_t;

	signal rgb_color : l_px_t;

	signal timer_ena : std_logic;
	signal timer_load, msec : i32_t;

	signal tx_ena, tx_busy, rx_busy : std_logic;
	signal tx_data, rx_data : string(1 to 64);
	signal tx_len, rx_len : integer range tx_data'range;
	signal rx_done : std_logic;

	signal state : integer range 0 to 6;

	signal curr_account : integer range 21 to 28;
	signal accounts : i16_arr_t(21 to 28) := (others => 2000);
	signal dot_scroll_row : integer range 0 to 7;
	signal key_buf : i4_arr_t(0 to 3);
	signal receipt_0, receipt_1, receipt_2 : string(1 to 4);

begin

	--!inc inst.vhd

	process (clk, rst_n) begin
		if rst_n = '0' then
			dot_r <= (others => (others => '1'));
			dot_g <= (others => (others => '1'));
			seg_data <= (others => '0');
			seg_dot <= (others => '0');
			l_bl <= 100;
			l_ena <= '1';
			l_addr <= 0;
			l_data <= white;
			led_r <= '0';
			led_g <= '0';
			led_y <= '0';
			rgb_color <= black;
			buz <= '0';
			timer_ena <= '0';
			timer_load <= 0;

			accounts <= (others => 2000);
			key_buf <= (others => 0);
			state <= 0;
		elsif rising_edge(clk) then
			if l_addr < l_addr'high then
				l_addr <= l_addr + 1;
			else
				l_addr <= 0;
			end if;

			if key_on_press = '1' then
				case key_lut(key) is
					when key_rst => state <= 0;
					when key_back =>
						if state > 0 then
							state <= state - 1;
						end if;
					when key_ok =>
						if state < state'high then
							state <= state + 1;
						end if;
					when others => null;
				end case;
			end if;

			tx_ena <= '0';
			if rx_done = '1' then
				if rx_data(1 to 6) = "!reset" then
					state <= 0;
				elsif rx_data(1 to 5) = "!init" then
					state <= 0;
				elsif rx_data(1 to 5) = "!idle" then
					state <= 1;
				elsif rx_data(1 to 7) = "!cardin" then
					state <= 2;
				elsif rx_data(1 to 6) = "!login" then
					tx_data(passwords(curr_account)'range) <= passwords(curr_account);
					tx_len <= passwords(curr_account)'length;
					tx_ena <= '1';
				end if;
			end if;

			case state is
				when 0 => -- init
					timer_ena <= '1';
					dot_r <= (others => (others => '1'));
					dot_g <= (others => (others => '1'));
					seg_data <= (others => '0');
					seg_dot <= (others => '0');
					l_bl <= 100;
					l_ena <= '1';
					l_addr <= 0;
					l_data <= white;
					led_r <= '0';
					led_g <= '0';
					led_y <= '0';
					rgb_color <= black;
					buz <= '0';

					if msec = 1000 then
						timer_load <= 0;
						timer_ena <= '0';
						state <= 1;
					end if;

				when 1 => -- idle
					timer_load <= 0;
					timer_ena <= '0';
					dot_r <= dot_logo_r;
					dot_g <= dot_logo_g;

				when 2 => -- card_in
					timer_load <= 0;
					timer_ena <= '0';

					seg_data <= (others => '0'); -- string 0
					seg_data <= (others => '0'); -- logic 0

					dot_r <= dot_up_r;
					dot_g <= dot_up_g;

					if reduce(sw_rising, "or_") = '1' then
						tx_data(1 to 2) <= to_string(index_of(sw_rising, '1') + 21, 99, 10, 2);
						tx_len <= 2;
						tx_ena <= '1';
						state <= 3;
					else
						tx_ena <= '0';
					end if;

				when 3 => -- login
					timer_load <= 0;
					timer_ena <= '0';
					tx_ena <= '0';

				when 4 => -- amount
					timer_load <= 0;
					timer_ena <= '0';

				when 5 => -- receipt
					timer_load <= 0;
					timer_ena <= '0';

					receipt_0 <= "24  ";
					receipt_1 <= "4592";
					receipt_2 <= "500 ";

					--!def lp_row2 l_paste_txt(l_addr, lp_row1, receipt_2(1) & "      " & receipt_2(2) & "      " & receipt_2(3) & "      " & receipt_2(4) , (129, 14))
					--!def lp_row1 l_paste_txt(l_addr, lp_row0, receipt_1(1) & "      " & receipt_1(2) & "      " & receipt_1(3) & "      " & receipt_1(4) , (76, 14))
					--!def lp_row0 l_paste_txt(l_addr, white, receipt_0(1) & "      " & receipt_0(2) & "      " & receipt_0(3) & "      " & receipt_0(4) , (23, 14))
					l_data <= lp_row2;

				when 6 => -- card_out
					timer_ena <= '1';
			end case;

			-- seg_data <= to_string(msec, 99999999, 10, 8);
			seg_data <= to_string(state, 99999999, 10, 8);
			-- seg_data <= to_string(key, 99999999, 10, 8);
			-- seg_dot <= repeat(key_on_press, 8);
		end if;
	end process;

end arch;

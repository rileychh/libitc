--!pp on
--!inc const_pkg.vhd

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;
use work.itc108_2_const.all;

entity itc109_2 is
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
end itc109_2;

architecture arch of itc109_2 is

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

	signal state : integer range 0 to 10;

	signal curr_account : integer range 1 to 3;
	signal accounts : i16_arr_t(1 to 3) := (1000, 2000, 3000);
	signal key_buf : string(1 to 4) := "0000";
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

			accounts <= (1000, 2000, 3000);
			key_buf <= (others => '0');
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
					when others => null;
				end case;
			end if;

			-- tx_ena <= '0';
			-- if rx_done = '1' then
			-- 	if rx_data(1 to 6) = "!reset" then
			-- 		state <= 0;
			-- 	elsif rx_data(1 to 5) = "!init" then
			-- 		state <= 0;
			-- 	elsif rx_data(1 to 5) = "!idle" then
			-- 		state <= 1;
			-- 	elsif rx_data(1 to 7) = "!cardin" then
			-- 		state <= 2;
			-- 	elsif rx_data(1 to 6) = "!login" then
			-- 		tx_data(passwords(curr_account)'range) <= passwords(curr_account);
			-- 		tx_len <= passwords(curr_account)'length;
			-- 		tx_ena <= '1';
			-- 	end if;
			-- end if;

			case state is
				when 0 => -- init
					timer_ena <= '1';
					dot_r <= (others => (others => '1'));
					dot_g <= (others => (others => '1'));
					seg_data <= (others => ' ');
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

					seg_data <= (others => '0'); -- string 0
					seg_dot <= (others => '0'); -- logic 0

					if reduce(sw, "or_") = '1' then
						dot_r <= (others => (others => '0'));
						dot_g <= dot_block;
					else
						dot_r <= dot_up;
						dot_g <= dot_up;
					end if;

					if key_on_press = '1' and key_lut(key) = key_ok then
						state <= 2;
						curr_account <= index_of(sw, '1') + 1;
					end if;
				when 2 => -- login
					dot_r <= (others => (others => '0'));
					dot_g <= dot_block;

					seg_data <= (others => '0'); -- string 0
					seg_dot <= (others => '0'); -- logic 0

					if tx_busy = '0' then
						tx_data(1 to 6) <= "!login";
						tx_len <= 6;
						tx_ena <= '1';
						state <= 3;
					else
						tx_ena <= '0';
					end if;

				when 3 => -- login (wait password)
					tx_ena <= '0';
					if rx_done = '1' then
						state <= 4;
					end if;

					dot_r <= (others => (others => '0'));
					dot_g <= dot_block;

					seg_data <= (others => '0'); -- string 0
					seg_dot <= (others => '0'); -- logic 0

				when 4 => -- login (wait ok)
					if key_on_press = '1' and key_lut(key) = key_ok then
						if rx_data(1 to 5) = passwords(curr_account) then -- correct
							curr_account <= index_of(sw, '1') + 1;
							state <= 5;
						else
							timer_ena <= '1';
						end if;
					end if;

					if timer_ena = '1' then
						case msec is
							when 1 =>
								buz <= '1';
							when 500 =>
								buz <= '0';
								state <= 6; -- card out
							when others => null;
						end case;
					end if;

				when 5 => -- amount
					timer_load <= 0;
					timer_ena <= '0';

					dot_r <= (others => (others => '0'));
					dot_g <= dot_block;

					seg_data <= to_string(accounts(curr_account), accounts(curr_account)'high, 10, 4) & key_buf;
					seg_dot <= (others => '0'); -- logic 0

					if key_on_press = '1' then
						case key_lut(key) is
							when 0 to 9 =>
								key_buf <= key_buf(2 to 4) & to_string(key_lut(key), 9, 10, 1);
							when others => null;
						end case;
					end if;

				when 6 => -- receipt
					timer_load <= 0;
					timer_ena <= '0';

					receipt_0 <= "24  ";
					receipt_1 <= "4592";
					receipt_2 <= "500 ";

					--!def lp_row2 l_paste_txt(l_addr, lp_row1, receipt_2(1) & "      " & receipt_2(2) & "      " & receipt_2(3) & "      " & receipt_2(4) , (129, 14))
					--!def lp_row1 l_paste_txt(l_addr, lp_row0, receipt_1(1) & "      " & receipt_1(2) & "      " & receipt_1(3) & "      " & receipt_1(4) , (76, 14))
					--!def lp_row0 l_paste_txt(l_addr, white, receipt_0(1) & "      " & receipt_0(2) & "      " & receipt_0(3) & "      " & receipt_0(4) , (23, 14))
					l_data <= lp_row2;

				when 7 => -- card_out
					timer_ena <= '1';
				when 8 => -- done (rgb)
				when others => null;
			end case;

			-- seg_data <= to_string(msec, 99999999, 10, 8);
			seg_data <= to_string(state, 99999999, 10, 8);
			-- seg_data <= to_string(key, 99999999, 10, 8);
			-- seg_dot <= repeat(key_on_press, 8);
		end if;
	end process;

end arch;

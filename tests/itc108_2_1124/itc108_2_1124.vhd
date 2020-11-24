--!pp on
--!inc const_pkg.vhd

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;
use work.itc108_2_const.all;

entity itc108_2_1124 is
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
		-- uart
		uart_rx : in std_logic;  -- receive pin
		uart_tx : out std_logic; -- transmit pin
		-- debug
		dbg_a, dbg_b : out u8r_t
	);
end itc108_2_1124;

architecture arch of itc108_2_1124 is

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

	type state_t is (init, idle, service, seat, meal, offer, pay);
	signal state : state_t;

begin

	--!inc inst.vhd

	process (clk, rst_n) begin
		if rst_n = '0' then
			dot_r <= (others => (others => '0'));
			dot_g <= (others => (others => '0'));
			seg_data <= (others => ' ');
			seg_dot <= (others => '0');
			l_bl <= 0;
			l_ena <= '0';
			l_addr <= 0;
			l_data <= black;
			rgb_color <= black;
		elsif rising_edge(clk) then
			case state is
				when init =>

				when idle =>
				when service =>
				when seat =>
				when meal =>
				when offer =>
				when pay =>
			end case;
		end if;
	end process;

end arch;

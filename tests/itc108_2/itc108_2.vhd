-- inc => include
-- pp => full target .vhd files to a file and formatter to mini
--!pp on
--!inc pkg.plist.vhd
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;
use work.itc108_2_const.all;

entity itc108_2 is
	--!inc port.init.vhd
end itc108_2;

architecture arch of itc108_2 is

	type mode_t is (idle, tft, dht, tsl, full);
	signal mode : mode_t;

	type state_t is (idle, execute);
	signal state : state_t;

	signal rst_i : std_logic;
	signal speed_level : integer range 1 to 3;
	signal prev_temp : integer range 0 to 99;

	signal timer_ena : std_logic;
	signal timer_load, msec : i32_t;
	-- key scan
	signal pressed, key_on_press : std_logic;
	signal key : i4_t;
	signal brightness : integer range 0 to 100;
	signal lcd_wr_ena : std_logic;
	signal pixel_addr : integer range 0 to lcd_pixel_cnt - 1;
	signal pixel_data : lcd_pixel_t;
	signal seg_data : string(1 to 8) := (others => ' ');
	signal seg_dot : u8r_t;
	signal temp : integer range 0 to 99;
	signal dir : std_logic;
	signal speed : i8_t;

	-- fake rs232 - uart
	signal tx_ena, tx_busy : std_logic;
	signal tx_data : u8_t;

	signal rx_busy, rx_err : std_logic;
	signal rx_data : u8_t;
	signal rx_done : std_logic;

	signal buf : u8_arr_t(0 to 63);
	signal buf_cnt : integer range buf'range;

	-- dot
	signal dot_data_r, dot_data_g : u8r_arr_t(0 to 7);

	-- fpga lock state
	signal lock : boolean;
begin

	--!inc port.plist.vhd

	process (clk, rst_n) begin
		if rst_n = '0' then
			mode <= idle;
			timer_ena <= '0';
			timer_load <= 0;
			seg_data <= (others => ' ');
			seg_dot <= (others => '0');

			-- uart
			tx_ena <= '0';
			buf_cnt <= 0;
			-- dot reset => full orange
			dot_data_r <= (others => (others => '1'));
			dot_data_g <= (others => (others => '1'));
		elsif rising_edge(clk) then
			--------------------------------------------------------------------------------
			-- a => 初始狀態
			-- b => 待機狀態
			-- c => 選擇服務
			-- d => 選擇座位
			-- e => 選擇餐點
			-- f => 活動優惠
			-- g => 付款
			-- h => 完成
			--------------------------------------------------------------------------------
			timer_ena <= '1';
			if key_on_press = '1' then
				tx_data <= to_unsigned(key, 8);
				tx_ena <= '1';
			else
				tx_ena <= '0';
			end if;
			if (msec < 1000) then
				-- reset => at first sec
				dot_data_r <= (others => (others => '1'));
				dot_data_g <= (others => (others => '1'));
			elsif (msec mod 1000) = 1 then
				-- logo icon
				dot_data_r <= (others => (others => '0'));
				dot_data_g <= (others => (others => '0'));
			else
				dot_data_r <= (others => (others => '0'));
				dot_data_g <= (others => (others => '0'));
				-- dot_data_r <= ("00101010", "10010100", x"aa")
			end if;
		end if;
	end process;

end arch;

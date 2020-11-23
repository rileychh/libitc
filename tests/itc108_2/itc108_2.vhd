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
	signal rst_i : std_logic;
	signal speed_level : integer range 1 to 3;
	signal prev_temp : integer range 0 to 99;

	signal timer_ena : std_logic;
	signal timer_load, msec : i32_t;
	-- key scan
	signal pressed, key_on_press : std_logic;
	signal key : i4_t;
	-- seg
	signal seg_data : string(1 to 8) := (others => ' ');
	signal seg_dot : u8r_t;
	-- ??
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
	signal lock : std_logic := '0';

	-- fpga state => from 題目 description
	--------------------------------------------------------------------------------
	-- a => 初始狀態 => init
	-- b => 待機狀態 => idle
	-- c => 選擇服務 => service
	-- d => 選擇座位 => seat
	-- e => 選擇餐點 => meal
	-- f => 活動優惠 => offer
	-- g => 付款 => pay
	-- h => 完成 => ok
	--------------------------------------------------------------------------------
	type mode_plist is (init, idle, service, seat, meal, offer, pay, ok);
	signal mode : mode_plist;

	-- eat method, 0 => out eat, 1 => in eat
	signal eat_method : std_logic := '0';
begin

	--!inc port.plist.vhd

	process (clk, rst_n) begin
		if rst_n = '0' then
			mode <= init;
			timer_ena <= '0';
			timer_load <= 0;
			seg_data <= (others => ' ');
			seg_dot <= (others => '0');

			-- uart
			tx_ena <= '0'; -- uart tx disabled (Boolean:default => false)
			buf_cnt <= 0;
			-- dot reset => full orange
			dot_data_r <= (others => (others => '1'));
			dot_data_g <= (others => (others => '1'));
			lock <= '0';
		elsif rising_edge(clk) then

			timer_ena <= '1';

			if (mode = init or mode = idle or mode = seat or mode = ok) then
				seg_data <= (others => '0');
			end if;

			-- when user key press action
			if key_on_press = '1' then
				-- 0 => reset, 3 => back, 7 => delete, 15 => check
				tx_data <= to_unsigned(key, 8);
				tx_ena <= '1';
				if lock = '0' then
					case key is
						when 0 =>
							-- {{ reset }}
							mode <= init;
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
							lock <= '0';
						when 15 =>
							if mode = idle then
								mode <= service;
								-- 傳送狀態
							elsif mode = service then
								-- 傳送狀態
								-- require empty site arr(rd)
								-- if(eat_method == "in") {{run below}}
								-- 		show empty site in dot
								-- 		mode <= seat;
								-- else
								-- 		mode <=	meal
							elsif mode = seat then
								-- require has chosen seat (include before chosen)
								mode <= meal;

							end if;
						when others => null;
					end case;
				end if;
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
				dot_data_r <= (x"0c", x"13", x"6c", x"90", x"60", x"80", x"00", x"00");
				dot_data_g <= (x"0c", x"10", x"60", x"83", x"0c", x"10", x"60", x"80");
				mode <= idle; -- chose service
				lock <= '0'; -- unlock driver
			else
				dot_data_r <= (others => (others => '0'));
				dot_data_g <= (others => (others => '0'));
				-- {{ you can use hex or binary }} => dot_data_r <= ("00101010", "10010100", x"aa")
				dot_data_r <= (x"0c", x"13", x"6c", x"90", x"60", x"80", x"00", x"00");
				dot_data_g <= (x"0c", x"10", x"60", x"83", x"0c", x"10", x"60", x"80");
			end if;
		end if;
	end process;

end arch;

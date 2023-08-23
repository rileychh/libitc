library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;

package itc109_1_const is
	constant key_start : integer := 3;
	constant key_rst : integer := 7;
	constant key_fn : integer := 11;
	constant key_up : integer := 2;
	constant key_down : integer := 6;
	constant key_ok : integer := 10;

	-- "測試", 4
	-- tts_data(tts_t_test'range) <= tts_t_test;
	-- tts_len <= tts_t_test'length;
	constant tts_t_test : u8_arr_t(0 to 3) := (
			x"b4", x"fa", x"b8", x"d5"
	);
end package;

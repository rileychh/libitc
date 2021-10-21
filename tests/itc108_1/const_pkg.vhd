library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;

package itc108_1_const is
	constant key_stop : integer := 1;
	constant key_rst : integer := 2;
	constant key_start : integer := 3;
	constant key_ok : integer := 5;
	constant key_down : integer := 6;
	constant key_up : integer := 7;

	--                                    lux      temp     speed
	constant tts_rpt_len : integer := 25 + 4 + 15 + 2 + 10 + 1 + 10 + 10; -- 77

	-- "智能居家控溫系統啟動 亮度", 25
	-- tts_data(0 to 24) <= txt_rpt_1;
	-- tts_len <= 25;
	constant txt_rpt_1 : u8_arr_t(0 to 24) := (
		x"b4", x"bc", x"af", x"e0", x"a9", x"7e", x"ae", x"61", x"b1", x"b1", x"b7", x"c5", x"a8", x"74", x"b2", x"ce",
		x"b1", x"d2", x"b0", x"ca", x"20", x"ab", x"47", x"ab", x"d7"
	);

	-- "勒克司 且溫度為", 15
	-- tts_data(0 to 14) <= txt_rpt_2;
	-- tts_len <= 15;
	constant txt_rpt_2 : u8_arr_t(0 to 14) := (
		x"b0", x"c7", x"a7", x"4a", x"a5", x"71", x"20", x"a5", x"42", x"b7", x"c5", x"ab", x"d7", x"ac", x"b0"
	);

	-- "度C 轉速為", 10
	-- tts_data(0 to 9) <= txt_rpt_3;
	-- tts_len <= 10;
	constant txt_rpt_3 : u8_arr_t(0 to 9) := (
		x"ab", x"d7", x"43", x"20", x"c2", x"e0", x"b3", x"74", x"ac", x"b0"
	);

	-- "順時鐘旋轉", 10
	-- tts_data(0 to 9) <= txt_rpt_4_cw;
	-- tts_len <= 10;
	constant txt_rpt_4_cw : u8_arr_t(0 to 9) := (
		x"b6", x"b6", x"ae", x"c9", x"c4", x"c1", x"b1", x"db", x"c2", x"e0"
	);

	-- "逆時鐘旋轉", 10
	-- tts_data(0 to 9) <= txt_rpt_4_ccw;
	-- tts_len <= 10;
	constant txt_rpt_4_ccw : u8_arr_t(0 to 9) := (
		x"b0", x"66", x"ae", x"c9", x"c4", x"c1", x"b1", x"db", x"c2", x"e0"
	);

	-- "轉速增加中", 10
	-- tts_data(0 to 9) <= txt_rpt_5_up;
	-- tts_len <= 10;
	constant txt_rpt_5_up : u8_arr_t(0 to 9) := (
		x"c2", x"e0", x"b3", x"74", x"bc", x"57", x"a5", x"5b", x"a4", x"a4"
	);

	-- "持續換氣中", 10
	-- tts_data(0 to 9) <= txt_rpt_5_same;
	-- tts_len <= 10;
	constant txt_rpt_5_same : u8_arr_t(0 to 9) := (
		x"ab", x"f9", x"c4", x"f2", x"b4", x"ab", x"ae", x"f0", x"a4", x"a4"
	);

	-- "轉速降低中", 10
	-- tts_data(0 to 9) <= txt_rpt_5_down;
	-- tts_len <= 10;
	constant txt_rpt_5_down : u8_arr_t(0 to 9) := (
		x"c2", x"e0", x"b3", x"74", x"ad", x"b0", x"a7", x"43", x"a4", x"a4"
	);
end package;

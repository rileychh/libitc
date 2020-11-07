library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package bruh_data is
    constant txt_len_max : integer := 46;

	-- "系統開機偵測環境數值，照度、溫度、濕度偵測完畢", 46
	-- tts_txt(0 to 45) <= txt_sensor_init;
	-- tts_txt_len <= 46;
	constant txt_sensor_init : txt_t(0 to 45) := (
		x"a8", x"74", x"b2", x"ce", x"b6", x"7d", x"be", x"f7", x"b0", x"bb", x"b4", x"fa", x"c0", x"f4", x"b9", x"d2",
		x"bc", x"c6", x"ad", x"c8", x"a1", x"41", x"b7", x"d3", x"ab", x"d7", x"a1", x"42", x"b7", x"c5", x"ab", x"d7",
		x"a1", x"42", x"c0", x"e3", x"ab", x"d7", x"b0", x"bb", x"b4", x"fa", x"a7", x"b9", x"b2", x"a6"
	);

	-- "智能居家控溫系統啟動", 20
	-- tts_txt(0 to 19) <= txt_combined_test_init;
	-- tts_txt_len <= 20;
	constant txt_combined_test_init : txt_t(0 to 19) := (
		x"b4", x"bc", x"af", x"e0", x"a9", x"7e", x"ae", x"61", x"b1", x"b1", x"b7", x"c5", x"a8", x"74", x"b2", x"ce",
		x"b1", x"d2", x"b0", x"ca"
	);

	-- "右聲道播放亮度為", 16
	-- tts_txt(0 to 15) <= txt_lux_prefix;
	-- tts_txt_len <= 16;
	constant txt_lux_prefix : txt_t(0 to 15) := (
		x"a5", x"6b", x"c1", x"6e", x"b9", x"44", x"bc", x"bd", x"a9", x"f1", x"ab", x"47", x"ab", x"d7", x"ac", x"b0"
	);

	-- "勒克司", 6
	-- tts_txt(0 to 5) <= txt_lux_suffix;
	-- tts_txt_len <= 6;
	constant txt_lux_suffix : txt_t(0 to 5) := (
		x"b0", x"c7", x"a7", x"4a", x"a5", x"71"
	);

	-- "左聲道播放溫度為", 16
	-- tts_txt(0 to 15) <= txt_temp_prefix;
	-- tts_txt_len <= 16;
	constant txt_temp_prefix : txt_t(0 to 15) := (
		x"a5", x"aa", x"c1", x"6e", x"b9", x"44", x"bc", x"bd", x"a9", x"f1", x"b7", x"c5", x"ab", x"d7", x"ac", x"b0"
	);

	-- "度C", 3
	-- tts_txt(0 to 2) <= txt_temp_suffix;
	-- tts_txt_len <= 3;
	constant txt_temp_suffix : txt_t(0 to 2) := (
		x"ab", x"d7", x"43"
	);

	-- "雙聲道播放濕度為", 16
	-- tts_txt(0 to 15) <= txt_hum_prefix;
	-- tts_txt_len <= 16;
	constant txt_hum_prefix : txt_t(0 to 15) := (
		x"c2", x"f9", x"c1", x"6e", x"b9", x"44", x"bc", x"bd", x"a9", x"f1", x"c0", x"e3", x"ab", x"d7", x"ac", x"b0"
	);

	-- "趴", 2
	-- tts_txt(0 to 1) <= txt_hum_suffix;
	-- tts_txt_len <= 2;
	constant txt_hum_suffix : txt_t(0 to 1) := (
		x"ad", x"77"
	);

	-- "右聲道播放亮度為關閉", 20
	-- tts_txt(0 to 19) <= txt_lux_off;
	-- tts_txt_len <= 20;
	constant txt_lux_off : txt_t(0 to 19) := (
		x"a5", x"6b", x"c1", x"6e", x"b9", x"44", x"bc", x"bd", x"a9", x"f1", x"ab", x"47", x"ab", x"d7", x"ac", x"b0",
		x"c3", x"f6", x"b3", x"ac"
	);

	-- "左聲道播放溫度為關閉", 20
	-- tts_txt(0 to 19) <= txt_temp_off;
	-- tts_txt_len <= 20;
	constant txt_temp_off : txt_t(0 to 19) := (
		x"a5", x"aa", x"c1", x"6e", x"b9", x"44", x"bc", x"bd", x"a9", x"f1", x"b7", x"c5", x"ab", x"d7", x"ac", x"b0",
		x"c3", x"f6", x"b3", x"ac"
	);

	-- "雙聲道播放濕度為關閉", 20
	-- tts_txt(0 to 19) <= txt_hum_off;
	-- tts_txt_len <= 20;
	constant txt_hum_off : txt_t(0 to 19) := (
		x"c2", x"f9", x"c1", x"6e", x"b9", x"44", x"bc", x"bd", x"a9", x"f1", x"c0", x"e3", x"ab", x"d7", x"ac", x"b0",
		x"c3", x"f6", x"b3", x"ac"
	);

	-- "再測試一次", 10
	-- tts_txt(0 to 9) <= txt_retry;
	-- tts_txt_len <= 10;
	constant txt_retry : txt_t(0 to 9) := (
		x"a6", x"41", x"b4", x"fa", x"b8", x"d5", x"a4", x"40", x"a6", x"b8"
	);

end package;
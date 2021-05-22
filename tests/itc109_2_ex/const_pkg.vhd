library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;

package itc108_2_const is
	constant key_lut : i4_arr_t(i4_t'range) := (
		1,  2,  3, 10,
		4,  5,  6, 11,
		7,  8,  9, 12,
		15, 0, 15, 13
	);
	constant key_back : i4_t := 10;
	constant key_rst : i4_t := 11;
	constant key_clr : i4_t := 12;
	constant key_ok : i4_t := 13;

	constant dot_logo_r : u8r_arr_t(0 to 7) := (x"0c", x"13", x"6c", x"90", x"60", x"80", x"00", x"00");
	constant dot_logo_g : u8r_arr_t(0 to 7) := (x"0c", x"10", x"60", x"83", x"0c", x"10", x"60", x"80");
	constant dot_up_r : u8r_arr_t(0 to 7) :=  (x"18", x"3c", x"7e", x"ff", x"3c", x"3c", x"3c", x"3c");
	constant dot_up_g : u8r_arr_t(0 to 7) :=  (x"18", x"3c", x"7e", x"ff", x"3c", x"3c", x"3c", x"3c");
	constant dot_down_r : u8r_arr_t(0 to 7) := (x"3c", x"3c", x"3c", x"3c", x"ff", x"7e", x"3c", x"18");
	constant dot_down_g : u8r_arr_t(0 to 7) := (x"3c", x"3c", x"3c", x"3c", x"ff", x"7e", x"3c", x"18");
	constant dot_true_r : u8r_arr_t(0 to 7) := (others => (others => '0'));
	constant dot_true_g : u8r_arr_t(0 to 7) := (x"18", x"24", x"42", x"81", x"81", x"42", x"24", x"18");
	constant dot_false_r : u8r_arr_t(0 to 7) := (x"81", x"42", x"24", x"18", x"18", x"24", x"42", x"81");
	constant dot_false_g : u8r_arr_t(0 to 7) := (others => (others => '0'));
 
	type passwords_t is array (21 to 28) of string(1 to 12);
	constant passwords : passwords_t := (
		"11111111====", "222222222===", "3333333333==", "44444444444=",
		"555555555555", "12345678====", "123456789===", "1234567890=="
	);

end package;

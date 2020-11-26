library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;

package itc108_2_const is
	constant key_lut : i4_arr_t(i4_t'range) := (
		1,  2,  3, 10,
		4,  5,  6, 11,
		7,  8,  9, 12,
		15, 0, 15, 15
	);
	constant key_rst : i4_t := 10;
	constant key_clr : i4_t := 11;
	constant key_ok : i4_t := 12;

	constant dot_block : u8r_arr_t(0 to 7) := (x"3c", x"3c", x"3c", x"3c", x"3c", x"3c", x"3c", x"3c");
	constant dot_up : u8r_arr_t(0 to 7) :=  (x"18", x"3c", x"7e", x"18", x"18", x"18", x"18", x"18");

	type passwords_t is array (1 to 3) of string(1 to 5);
	constant passwords : passwords_t := (
		"12345", "23456", "34567"
	);

end package;

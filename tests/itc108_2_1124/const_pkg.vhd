library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;

package itc108_2_const is
	constant key_lut : i4_arr_t(i4'range) := (
		15, 15, 15, 15,
		1,  2,  3,  10,
		4,  5,  6,   0,
		7,  8,  9,  11
	);
	constant key_clr : i4_t := 10;
	constant key_ok : i4_t := 11;
end package;

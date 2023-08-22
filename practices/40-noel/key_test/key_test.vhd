library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.itc.all;

entity key_test is
	port (
		clk, rst_n       : in std_logic;
		seg_led, seg_com : out u8r_t;
		dot              : out u8r_t);
end key_test;

architecture arch of key_test is
	signal key_data : string(1 to 8);
	signal d : u8r_t;
begin
	seg_inst : entity work.seg(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			seg_led => seg_led,
			seg_com => seg_com,
			data    => key_data,
			dot     => d
		);
	key_data <= "S  0    ";

end architecture;

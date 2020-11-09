library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;

entity dot_test is
	port (
		-- sys
		clk, rst_n : in std_logic;
		-- dot
		dot_r, dot_g, dot_s : out byte_be_t;
		-- sw 
		sw : in byte_t
	);
end dot_test;

architecture arch of dot_test is

	-- test buffers for dot
	constant test_buf_r : bytes_be_t(0 to 7) := ("11111111", "10000001", "10111101", "10100101", "10100101", "10111101", "10000001", "11111111");
	constant test_buf_g : bytes_be_t(0 to 7) := ("11111111", "11111111", "11000011", "11011011", "11011011", "11000011", "11111111", "11111111");

begin

	dot_inst : entity work.dot(arch)
		port map(
			clk    => clk,
			rst_n  => rst_n,
			dot_r  => dot_r,
			dot_g  => dot_g,
			dot_s  => dot_s,
			data_r => test_buf_r,
			data_g => test_buf_g
		);

end arch;

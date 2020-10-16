library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.clk_p.all;
use work.dot_p.all;

entity dot_test is

	port (
		-- sys
		sys_clk, sys_rst : in std_logic;
		-- dot
		dot_r, dot_g, dot_s : out unsigned(0 to 7);
		-- sw 
		sw : in unsigned(7 downto 0)
	);

end dot_test;

architecture arch of dot_test is

	constant zeros : dot_data_t := (others => (others => '0'));
	constant ones : dot_data_t := (others => (others => '1'));
	-- test buffer for dot
	constant test_buf_r : dot_data_t := ("01111111", "11111111", "11111111", "11111111", "00011000", "00011000", "00000000", "00000001");
	constant test_buf_g : dot_data_t := ("10000000", "00000000", "00011000", "00011000", "11111111", "11111111", "11111111", "11111110");

	signal clk_1k : std_logic;
	signal dot_data_r, dot_data_g : dot_data_t;
	signal frame_cnt : integer range 0 to 3;

begin

	clk_sys_inst : entity work.clk_sys(arch)
		generic map(
			clk_out_freq => 1_000
		)
		port map(
			sys_clk => sys_clk,
			sys_rst => sys_rst,
			clk_out => clk_1k
		);

	dot_inst : entity work.dot(arch)
		port map(
			dot_r  => dot_r,
			dot_g  => dot_g,
			dot_s  => dot_s,
			clk    => clk_1k,
			data_r => dot_data_r,
			data_g => dot_data_g
		);

	dot_data_r <= test_buf_r;
	dot_data_g <= test_buf_g;

end arch;
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;

entity tsl_test is
	port (
		-- sys
		clk, rst_n : in std_logic; -- rising edge clock, low reset
		-- seg
		seg_1, seg_2, seg_s : out byte_be_t; -- abcdefgp * 2, seg2_s1 ~ seg1_s4
		-- tsl
		tsl_scl, tsl_sda : inout std_logic;
		-- dbg
		dbg_a, dbg_b : out std_logic_vector(0 to 7)
	);
end tsl_test;

architecture arch of tsl_test is

	signal tsl_lux : integer range 0 to 40000;

begin

	dbg_a(0) <= tsl_sda;
	dbg_a(1) <= tsl_scl;

	tsl_inst : entity work.tsl(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			tsl_scl => tsl_scl,
			tsl_sda => tsl_sda,
			lux     => tsl_lux
		);

	seg_inst : entity work.seg(arch)
		port map(
			clk   => clk,
			rst_n => rst_n,
			seg_1 => seg_1,
			seg_2 => seg_2,
			seg_s => seg_s,
			data  => to_string(tsl_lux, tsl_lux'high, 10, 5) & "LUX",
			dot => (others => '0')
		);

end arch;

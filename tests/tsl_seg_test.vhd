library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.seg_p.all;
use work.tsl_p.all;

entity tsl_seg_test is
	port (
		-- sys
		sys_clk, sys_rst : in std_logic; -- rising edge clock, low reset
		-- seg
		seg_1, seg_2 : out unsigned(7 downto 0); -- abcdefgp * 2
		seg_s        : out unsigned(0 to 7);     -- seg2_s1 ~ seg1_s4
		-- tsl
		tsl_scl, tsl_sda : inout std_logic
	);
end tsl_seg_test;

architecture arch of tsl_seg_test is

	signal tsl_lux : integer range 0 to 40000;
	signal seg_data : string(1 to 8);

	signal dbg_state : integer range 0 to 8;
	signal tsl_state : integer range 0 to 3;
	signal dbg_reg : integer range 0 to 4;
	signal dbg_cnt : integer range 0 to 8;

begin

	tsl_inst : entity work.tsl(arch)
		port map(
			tsl_scl   => tsl_scl,
			tsl_sda   => tsl_sda,
			clk       => sys_clk,
			rst       => sys_rst,
			lux       => tsl_lux,
			dbg_state => dbg_state,
			tsl_state => tsl_state,
			dbg_reg   => dbg_reg,
			dbg_cnt   => dbg_cnt
		);

	seg_inst : entity work.seg(arch)
		port map(
			seg_1 => seg_1,
			seg_2 => seg_2,
			seg_s => seg_s,
			clk   => sys_clk,
			data  => seg_data,
			dot => (others => '0')
		);
	seg_map : for i in 0 to 3 generate
		seg_data(3 - i + 1) <= to_character(to_bcd(tsl_lux, 16, 4)(i * 4 + 3 downto i * 4)); -- tsl_lux
	end generate seg_map;
	seg_data(5) <= to_character(dbg_cnt);
	seg_data(6) <= to_character(dbg_state);
	seg_data(7) <= to_character(tsl_state);
	seg_data(8) <= to_character(dbg_reg);

end arch;
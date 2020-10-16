library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.clk_p.all;
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
		tsl_scl : out std_logic;
		tsl_sda : inout std_logic
	);
end tsl_seg_test;

architecture arch of tsl_seg_test is

	signal clk_800k, clk_1k : std_logic;
	signal tsl_lux : integer;
	signal tsl_lux_bcd : unsigned(15 downto 0); -- 4 digits
	signal seg_data : string(1 to 8);
	signal dbg_i2c_state : unsigned(2 downto 0);

begin

	clk_sys_inst_800k : entity work.clk_sys(arch)
		generic map(
			clk_out_freq => 800_000
		)
		port map(
			sys_clk => sys_clk,
			sys_rst => sys_rst,
			clk_out => clk_800k
		);

	clk_sys_inst_1k : entity work.clk_sys(arch)
		generic map(
			clk_out_freq => 1_000
		)
		port map(
			sys_clk => sys_clk,
			sys_rst => sys_rst,
			clk_out => clk_1k
		);

	tsl_inst : entity work.tsl(arch)
		port map(
			tsl_scl       => tsl_scl,
			tsl_sda       => tsl_sda,
			clk           => clk_800k,
			rst           => sys_rst,
			lux           => tsl_lux,
			dbg_i2c_state => dbg_i2c_state
		);

	seg_inst : entity work.seg(arch)
		port map(
			seg_1 => seg_1,
			seg_2 => seg_2,
			seg_s => seg_s,
			clk   => clk_1k,
			data  => seg_data,
			dot => (others => '0')
		);

	-- map bcd version of tsl_lux to seven segment display data input
	seg_map : for i in 0 to 7 generate
		left : if i >= 0 and i < 4 generate -- 0 to 3
			seg_data(4 - i) <= to_character(to_bcd(tsl_lux, 13, 4)(i * 4 + 3 downto i * 4)); -- tsl_lux
		end generate left;

		right : if i >= 4 and i < 7 generate -- 4 to 6
			seg_data(i + 1) <= ' '; -- spaces (blank)
		end generate right;

		dbg : if i = 7 generate
			seg_data(i + 1) <= to_character(to_bcd(to_integer(dbg_i2c_state), 3, 1));
		end generate dbg;
	end generate seg_map;

end arch;
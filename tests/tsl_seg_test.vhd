library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.clk_p.all;
use work.seg_p.all;
use work.bcd_p.all;
use work.tsl_p.all;

entity tsl_seg_test is
	port (
		-- sys
		sys_clk, sys_rst : in std_logic; -- rising edge clock, low reset
		-- seg
		seg_1, seg_2, seg_s : out unsigned(7 downto 0); -- abcdefgp * 2, seg2_s1 ~ seg1_s4
		-- tsl
		tsl_scl : out std_logic;
		tsl_sda : inout std_logic
	);
end tsl_seg_test;

architecture arch of tsl_seg_test is

	signal clk_800k, clk_1k : std_logic;
	signal tsl_lux : integer;
	signal tsl_lux_bcd : unsigned(15 downto 0); -- 4 digits
	signal seg_data : seg_data_t;

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
			tsl_scl => tsl_scl,
			tsl_sda => tsl_sda,
			clk     => clk_800k,
			rst     => sys_rst,
			lux     => tsl_lux
		);

	seg_inst : entity work.seg(arch)
		port map(
			seg_1 => seg_1,
			seg_2 => seg_2,
			seg_s => seg_s,
			clk   => clk_1k,
			ena   => '1',
			data  => seg_data
		);

	to_bcd_inst : entity work.to_bcd(arch)
		generic map(
			bin_width => 13, -- up to 8192
			digit_len => 4
		)
		port map(
			bin => to_unsigned(tsl_lux, 13),
			bcd => tsl_lux_bcd
		);

	-- map bcd version of tsl_lux to seven segment display data input
	seg_bcd : for i in 0 to 3 generate
		seg_data(3 - i) <= to_integer(tsl_lux_bcd(i * 4 + 3 downto i * 4));
	end generate seg_bcd;

end arch;
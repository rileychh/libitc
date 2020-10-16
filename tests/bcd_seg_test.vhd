-- BCD counter

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.clk_p.all;
use work.seg_p.all;

entity bcd_seg_test is

	port (
		-- sys
		sys_clk, sys_rst : in std_logic;
		-- sw
		sw : in unsigned(7 downto 0);
		-- seg
		seg_1, seg_2 : out unsigned(7 downto 0); -- abcdefgp * 2
		seg_s        : out unsigned(0 to 7)      -- seg2_s1 ~ seg1_s4
	);

end bcd_seg_test;

architecture arch of bcd_seg_test is

	signal clk_100, clk_1k, clk_10k, clk_cnt : std_logic;
	signal cnt : integer range 0 to 99_999_999 := 0;
	signal seg_data : string(1 to 8);

begin

	clk_sys_inst_10k : entity work.clk_sys(arch)
		generic map(
			clk_out_freq => 10000
		)
		port map(
			sys_clk => sys_clk,
			sys_rst => sys_rst,
			clk_out => clk_10k
		);

	clk_div_inst_1k : entity work.clk_div(arch)
		generic map(
			divisor => 10
		)
		port map(
			sys_rst => sys_rst,
			clk_in  => clk_10k,
			clk_out => clk_1k
		);

	clk_div_inst_100 : entity work.clk_div(arch)
		generic map(
			divisor => 10
		)
		port map(
			sys_rst => sys_rst,
			clk_in  => clk_1k,
			clk_out => clk_100
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

	seg_map : for i in 0 to 7 generate
		seg_data(8 - i) <= to_character(to_bcd(cnt, 27, 8)(i * 4 + 3 downto i * 4));
	end generate seg_map;

	with sw(1 downto 0) select clk_cnt <=
	'0' when "00",
	clk_100 when "01",
	clk_1k when "10",
	clk_10k when "11";

	process (clk_cnt) begin 
		if rising_edge(clk_cnt) then
			cnt <= cnt + 1;
		end if; 
	end process;

end arch;
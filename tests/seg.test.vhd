-- BCD counter

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;

entity seg_test is
	port (
		-- system
		clk, rst_n : in std_logic;
		-- sw
		sw : in u8r_t;
		-- seg
		seg_led, seg_com : out u8r_t
	);
end seg_test;

architecture arch of seg_test is

	signal clocks : u8r_t;
	signal clk_cnt : std_logic;
	signal base : integer range 1 to 16;
	signal cnt : integer range 0 to 99_999_999 := 0;

begin

	clk_gen : for i in 0 to 7 generate
		clk_inst : entity work.clk(arch)
			generic map(
				freq => 10 ** i
			)
			port map(
				clk_in  => clk,
				rst_n   => rst_n,
				clk_out => clocks(i)
			);
	end generate clk_gen;

	seg_inst : entity work.seg(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			seg_led => seg_led,
			seg_com => seg_com,
			data    => to_string(cnt, cnt'high, base, 8),
			dot => (others => '0')
		);
	with to_integer(reverse(sw(0 to 1))) select base <=
	2 when 0,
	8 when 1,
	10 when 2,
	16 when others; -- 3

	clk_cnt <= clocks(to_integer(reverse(sw(5 to 7))));

	process (clk_cnt, rst_n) begin
		if rst_n = '0' then
			cnt <= 0;
		elsif rising_edge(clk_cnt) then
			if cnt = cnt'high then
				cnt <= 0;
			else
				cnt <= cnt + 1;
			end if;
		end if;
	end process;

end arch;

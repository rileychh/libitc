library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;

entity sw is
	port (
		-- system
		clk, rst_n : in std_logic;
		-- sw
		sw : in byte_t;
		-- user logic
		sw_out : out byte_t
	);
end sw;

architecture arch of sw is

begin

	debounce_gen : for i in 0 to 7 generate
		debounce_inst : entity work.debounce(arch)
			generic map(
				stable_time => 10
			)
			port map(
				clk     => clk,
				rst_n   => rst_n,
				sig_in  => sw(i),
				sig_out => sw_out(i)
			);
	end generate debounce_gen;

end arch;

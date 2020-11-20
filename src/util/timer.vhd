library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;

entity timer is
	port (
		-- system
		clk, rst_n : in std_logic;
		-- user logic
		ena  : in std_logic;
		load : in i32_t;
		msec : out i32_t
	);
end timer;

architecture arch of timer is

	signal clk_timer : std_logic;

begin

	clk_inst : entity work.clk(arch)
		generic map(
			freq => 1_000
		)
		port map(
			clk_in  => clk,
			rst_n   => rst_n,
			clk_out => clk_timer
		);

	process (clk_timer, rst_n) begin
		if rst_n = '0' then
			msec <= 0;
		elsif rising_edge(clk_timer) then
			if ena = '1' then
				msec <= msec + 1;
			else
				msec <= load;
			end if;
		end if;
	end process;

end arch;

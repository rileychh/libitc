library ieee;
use ieee.std_logic_1164.all;

use work.itc.all;

entity clk is
	generic (
		freq : integer := 1000
	);

	port (
		-- system
		clk_in : in std_logic;
		rst_n  : in std_logic;
		-- user logic
		clk_out : buffer std_logic
	);
end clk;

architecture arch of clk is

	signal cnt : integer range 0 to sys_clk_freq / freq / 2 - 1;

begin

	process (clk_in, rst_n) begin
		if rst_n = '0' then
			clk_out <= '0';
			cnt <= 0;
		elsif rising_edge(clk_in) then
			if cnt = cnt'high then
				cnt <= 0;
				clk_out <= not clk_out;
			else
				cnt <= cnt + 1;
			end if;
		end if;
	end process;

end arch;

library ieee;
use ieee.std_logic_1164.all;

entity edge is
	port (
		-- system
		clk, rst_n : in std_logic;
		-- user logic
		sig_in          : in std_logic;
		rising, falling : out std_logic
	);
end edge;

architecture arch of edge is

	signal prev_1 : std_logic;
	signal prev_2 : std_logic;

begin

	process (clk, rst_n) begin
		if rst_n = '0' then
			prev_1 <= '0';
			prev_2 <= '0';
		elsif rising_edge(clk) then
			prev_1 <= sig_in;
			prev_2 <= prev_1;
		end if;
	end process;
	rising <= not prev_2 and prev_1;
	falling <= prev_2 and not prev_1;

end arch;

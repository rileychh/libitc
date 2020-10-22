library ieee;
use ieee.std_logic_1164.all;

package clk_p is
	constant sys_clk_freq : integer := 50_000_000; -- OSC1 = 50MHz

	component clk
		generic (
			freq : integer := 1000
		);

		port (
			-- system
			clk_in : in std_logic;
			rst    : in std_logic;
			-- internal
			clk_out : out std_logic
		);
	end component;
end package;

library ieee;
use ieee.std_logic_1164.all;

use work.clk_p.all;

entity clk is
	generic (
		freq : integer := 1000
	);

	port (
		-- system
		clk_in : in std_logic;
		rst    : in std_logic;
		-- user logic
		clk_out : buffer std_logic
	);
end clk;

architecture arch of clk is

	constant cnt_high : integer := sys_clk_freq / freq / 2 - 1;
	signal cnt : integer range 0 to cnt_high;

begin

	process (clk_in, rst) begin
		if rst = '0' then
			clk_out <= '0';
			cnt <= 0;
		elsif rising_edge(clk_in) then
			if cnt = cnt_high then
				clk_out <= not clk_out;
			end if;

			cnt <= cnt + 1;
		end if;
	end process;

end arch;
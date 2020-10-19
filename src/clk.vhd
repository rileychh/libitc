library ieee;
use ieee.std_logic_1164.all;

package clk_p is
	constant sys_clk_freq : integer := 50_000_000; -- OSC1 = 50MHz

	component clk_sys
		generic (
			clk_out_freq : integer := 1000
		);

		port (
			-- system
			sys_clk : in std_logic;
			sys_rst : in std_logic;
			-- internal
			clk_out : out std_logic
		);
	end component;
end package;

library ieee;
use ieee.std_logic_1164.all;

use work.clk_p.all;

entity clk_sys is
	generic (
		clk_out_freq : integer := 1000
	);

	port (
		-- system
		sys_clk : in std_logic;
		sys_rst : in std_logic;
		-- internal
		clk_out : buffer std_logic
	);
end clk_sys;

architecture arch of clk_sys is

	signal cnt : integer range 0 to sys_clk_freq / clk_out_freq / 2 - 1;

begin

	process (sys_clk, sys_rst) begin 
		if sys_rst = '0' then
			clk_out <= '0';
			cnt <= 0;
		elsif rising_edge(sys_clk) then
			if cnt = cnt'high then
				clk_out <= not clk_out;
			end if;

			cnt <= cnt + 1;
		end if; 
	end process;

end arch;
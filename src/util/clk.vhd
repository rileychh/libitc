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
			-- user logic
			clk_out : out std_logic
		);
	end component;

	component edge
		port (
			-- system
			clk : in std_logic;
			rst : in std_logic;
			-- user logic
			signal_in : in std_logic;
			rising    : out std_logic;
			falling   : out std_logic
		);
	end component;
end package;

--
-- clock divider
--

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
				cnt <= 0;
				clk_out <= not clk_out;
			else
				cnt <= cnt + 1;
			end if;
		end if;
	end process;

end arch;

--
-- edge detector
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity edge is
	port (
		-- system
		clk : in std_logic;
		rst : in std_logic;
		-- user logic
		signal_in : in std_logic;
		rising    : out std_logic;
		falling   : out std_logic
	);
end edge;

architecture arch of edge is

	signal prev_1 : std_logic;
	signal prev_2 : std_logic;

begin

	process (clk, rst) begin
		if rst = '0' then
			prev_1 <= '0';
			prev_2 <= '0';
		elsif rising_edge(clk) then
			prev_1 <= signal_in;
			prev_2 <= prev_1;
		end if;
	end process;
	rising <= not prev_2 and prev_1;
	falling <= prev_2 and not prev_1;

end arch;
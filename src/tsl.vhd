library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tsl is

	port (
		-- tsl
		tsl_scl : out std_logic;
		tsl_sda : inout std_logic;
		-- internal
		clk : in std_logic; -- any frequency
		lux : out integer
	);

end tsl;

architecture arch of tsl is

begin

end arch;
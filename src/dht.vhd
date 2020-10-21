library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dht is
	port (
		-- dht
		dht_data : inout std_logic;
		-- internal
		clk : in std_logic;
		rst : in std_logic;
		temp : out integer range 0 to 50;
		hum : out integer range 20 to 80
	);
end dht;

architecture arch of dht is
	
begin
	-- TODO complete this
end arch;
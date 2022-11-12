library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;

entity dht_test is
	port (
		-- sys
		clk, rst_n : in std_logic;
		-- dht
		dht_data : inout std_logic;
		-- seg
		seg_led, seg_com : out u8r_t
	);
end dht_test;

architecture arch of dht_test is

	signal temp_int, hum_int : integer range 0 to 99;
	signal temp_dec, hum_dec : integer range 0 to 9;
	signal seg_data : string(1 to 8);

begin

	dht_inst : entity work.dht(arch)
		port map(
			clk      => clk,
			rst_n    => rst_n,
			dht_data => dht_data,
			temp_int => temp_int,
			temp_dec => temp_dec,
			hum_int  => hum_int,
			hum_dec  => hum_dec
		);

	seg_inst : entity work.seg(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			seg_led => seg_led,
			seg_com => seg_com,
			data    => to_string(temp_int, temp_int'high, 10, 2) &
			to_string(temp_dec, temp_dec'high, 10, 1) & 'C' &
			to_string(hum_int, hum_int'high, 10, 2) &
			to_string(hum_dec, hum_dec'high, 10, 1) & 'H',
			dot => (1 | 5 => '1', others => '0')
		);

end arch;

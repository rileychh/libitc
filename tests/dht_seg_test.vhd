library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.dht_p.all;
use work.seg_p.all;
use work.dot_p.all;

entity dht_seg_test is
	port (
		-- sys
		sys_clk : in std_logic;
		sys_rst : in std_logic;
		-- dht
		dht_data : inout std_logic;
		-- seg
		seg_1, seg_2 : out unsigned(7 downto 0); -- abcdefgp * 2
		seg_s        : out unsigned(0 to 7)      -- seg2_s1 ~ seg1_s4
	);
end dht_seg_test;

architecture arch of dht_seg_test is

	signal dht_temp : integer range 0 to 50;
	signal dht_hum : integer range 0 to 80;
	signal seg_data : string(1 to 8);
	signal dot_data_r : dot_data_t;

begin

	dht_inst : entity work.dht(arch)
		port map(
			dht_data => dht_data,
			clk      => sys_clk,
			rst      => sys_rst,
			temp     => dht_temp,
			hum      => dht_hum
		);

	seg_inst : entity work.seg(arch)
		port map(
			seg_1 => seg_1,
			seg_2 => seg_2,
			seg_s => seg_s,
			clk   => sys_clk,
			data  => seg_data,
			dot => (others => '0')
		);
	seg_data(1) <= to_character(to_bcd(dht_temp, 8, 2)(7 downto 4)); -- temperature tens
	seg_data(2) <= to_character(to_bcd(dht_temp, 8, 2)(3 downto 0)); -- temperature units
	seg_data(3 to 4) <= " C";
	seg_data(5) <= to_character(to_bcd(dht_hum, 8, 2)(7 downto 4)); -- humidity tens
	seg_data(6) <= to_character(to_bcd(dht_hum, 8, 2)(3 downto 0)); -- humidity units
	seg_data(7 to 8) <= " H";

end arch;
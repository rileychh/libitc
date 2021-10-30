library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;

entity tsl_test is
	port (
		-- sys
		clk, rst_n : in std_logic; -- rising edge clock, low reset
		-- seg
		seg_led, seg_com : out u8r_t;
		-- tsl
		tsl_scl, tsl_sda : inout std_logic;
		-- dbg
		dbg_a, dbg_b : out u8r_t
	);
end tsl_test;

architecture arch of tsl_test is

	signal tsl_lux : i16_t;

begin

	dbg_a <= tsl_sda & tsl_scl & "000000";
	-- dbg_b <= reverse(tsl_dbg);
	dbg_b <= (others => '0');

	tsl_inst : entity work.tsl(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			tsl_scl => tsl_scl,
			tsl_sda => tsl_sda,
			lux     => tsl_lux
		);

	seg_inst : entity work.seg(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			seg_led => seg_led,
			seg_com => seg_com,
			data    => to_string(tsl_lux, tsl_lux'high, 10, 5) & "LUX",
			dot => (others => '0')
		);

end arch;

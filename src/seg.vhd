library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package seg_p is
	-- length of seg_lut_len
	constant seg_lut_len : integer := 74;
	-- add seg_dot to any element of seg_data to turn on the dot
	-- e.g.:
	-- "123.456 °C" would be (1, 2, 3 + seg_dot, 4, 5, 6, seg_spc, 35, 12)
	constant seg_dot : integer := seg_lut_len / 2;
	constant seg_spc : integer := 33; -- space
	constant seg_deg : integer := 34; -- degree symbol
	constant seg_lb : integer := 35; -- [
	constant seg_rb : integer := 36; -- ]

	type seg_data_t is array(0 to 7) of integer range 0 to seg_lut_len - 1;

	component seg
		port (
			-- seg
			seg_1, seg_2, seg_s : out unsigned(7 downto 0); -- abcdefgp * 2, seg2_s1 ~ seg1_s4
			-- internal
			clk  : in std_logic; -- 1kHz
			ena  : in std_logic; -- '1' active, '0' blanks all leds
			data : in seg_data_t
		);
	end component;
end package;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.seg_p.all;

entity seg is
	port (
		-- seg
		seg_1, seg_2, seg_s : out unsigned(7 downto 0); -- abcdefgp * 2, seg2_s1 ~ seg1_s4
		-- internal
		clk  : in std_logic; -- 1kHz
		ena  : in std_logic; -- '1' active, '0' blanks all leds
		data : in seg_data_t
	);
end seg;

architecture arch of seg is

	-- look up table (decoder)
	type seg_lut_t is array(0 to seg_lut_len - 1) of unsigned(7 downto 0);
	constant lut : seg_lut_t := ( -- look-up table for decoding
	-- 0 to 15: 0123456789AbCdEF
	x"fc", x"60", x"da", x"f2", x"66", x"b6", x"be", x"e0",
	x"fe", x"f6", x"ee", x"3e", x"9c", x"7a", x"9e", x"8e",
	-- 16 to 32: GHhiJLnOoPqrStUuy
	x"bc", x"6e", x"2e", x"0c", x"78", x"1c", x"2a", x"fc",
	x"3a", x"ce", x"e6", x"0a", x"b6", x"1e", x"7c", x"38",
	x"76",
	-- 33 to 36: space, degree symbol, [, ]
	x"00", x"c6", x"9c", x"f0",
	-- same as all above but with dot
	x"fd", x"61", x"db", x"f3", x"67", x"b7", x"bf", x"e1",
	x"ff", x"f7", x"ef", x"3f", x"9d", x"7b", x"9f", x"8f",
	x"bd", x"6f", x"2f", x"0d", x"79", x"1d", x"2b", x"fd",
	x"3b", x"cf", x"e7", x"0b", x"b7", x"1f", x"7d", x"39",
	x"77", x"01", x"c7", x"9d", x"f1"
	);

	signal scan_cnt : integer range 0 to 7; -- segment scan count, for shifting seg_s
	signal led : unsigned(7 downto 0); -- splits into seg_1 and seg_2

begin

	seg_1 <= led;
	seg_2 <= led;

	process (clk)

	begin

		if rising_edge(clk) and ena = '1' then
			seg_s <= "01111111" ror scan_cnt; -- rotates '0' because common cathode
			led <= lut(data(scan_cnt)); -- get the digit, then filter though look-up table
			scan_cnt <= scan_cnt + 1;
		end if;

	end process;

end arch;
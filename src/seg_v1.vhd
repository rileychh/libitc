library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package seg_p is
	type seg_data_t is array(0 to 7) of integer range 0 to 15;

	component seg
		port (
			-- seg
			seg_1, seg_2, seg_s : out unsigned(7 downto 0); -- abcdefgp * 2, seg2_s1 ~ seg1_s4
			-- internal
			seg_clk  : in std_logic; -- 1kHz
			seg_data : in seg_data_t
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
		seg_clk  : in std_logic; -- 1kHz
		seg_data : in seg_data_t
	);
end seg;

architecture arch of seg is

	-- look up table (decoder)
	type seg_lut_t is array(0 to 15) of unsigned(7 downto 0);
	constant seg_lut : seg_lut_t := (
	-- 0 ~ f
	x"fc", x"60", x"da", x"f2",
	x"66", x"b6", x"be", x"e0",
	x"fe", x"f6", x"ee", x"3e",
	x"9c", x"7a", x"9e", x"8e"
	);

	signal scan_cnt : integer range 0 to 7; -- segment scan count, for shifting seg_s
	signal led      : unsigned(7 downto 0); -- splits into seg_1 and seg_2

begin

	seg_1 <= led;
	seg_2 <= led;

	process (seg_clk)

	begin

		if rising_edge(seg_clk) then
			seg_s    <= "01111111" ror scan_cnt;     -- rotates '0' because common cathode
			led      <= seg_lut(seg_data(scan_cnt)); -- get the digit, then filter though LUT
			scan_cnt <= scan_cnt + 1;
		end if;

	end process;

end arch;
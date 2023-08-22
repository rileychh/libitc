library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;

entity seg is
	generic (
		common_anode : std_logic := '1'
	);
	port (
		-- system
		clk, rst_n : in std_logic;
		-- seg
		seg_led, seg_com : out u8r_t;
		-- use logic
		data : in string(1 to 8); -- string type only allow positive range
		dot  : in u8r_t           -- dots are individually controlled
	);
end seg;

architecture arch of seg is

	-- decoder look up table
	type lut_t is array(0 to 2 ** 7 - 1) of u8r_t;
	constant lut : lut_t := (
		-- HACK add additional characters between 0 to 31
		-- reference these using `character'val(0)` to `character'val(31)` or constants in itc.pkg.vhd
		x"c6", x"80", x"40", x"20", x"10", x"08", x"04", x"02", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00",
		x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00",
		-- ASCII printable characters (SPC to DEL)
		x"00", x"61", x"44", x"7e", x"b6", x"4b", x"62", x"04", x"94", x"d0", x"84", x"0e", x"08", x"02", x"01", x"4a",
		x"fc", x"60", x"da", x"f2", x"66", x"b6", x"be", x"e0", x"fe", x"f6", x"90", x"b0", x"86", x"12", x"c2", x"cb",
		x"fa", x"ee", x"3e", x"9c", x"7a", x"9e", x"8e", x"bc", x"6e", x"0c", x"78", x"ae", x"1c", x"aa", x"ec", x"fc",
		x"ce", x"d6", x"cc", x"b6", x"1e", x"7c", x"7c", x"54", x"92", x"76", x"da", x"9c", x"26", x"f0", x"c4", x"10",
		x"40", x"fa", x"3e", x"1a", x"7a", x"de", x"8e", x"f6", x"2e", x"08", x"30", x"ae", x"0c", x"28", x"2a", x"3a",
		x"ce", x"e6", x"0a", x"b6", x"1e", x"38", x"30", x"28", x"92", x"76", x"da", x"62", x"0c", x"0e", x"80", x"00"
	);

	signal clk_scan : std_logic;
	signal digit : integer range 0 to 7;

begin

	clk_inst : entity work.clk(arch)
		generic map(
			freq => 1_000
		)
		port map(
			clk_in  => clk,
			rst_n   => rst_n,
			clk_out => clk_scan
		);

	process (clk_scan, rst_n)
	begin
		if rst_n = '0' then
			digit <= 0;
		elsif rising_edge(clk_scan) then
			if digit = digit'high then
				digit <= 0;
			else
				digit <= digit + 1;
			end if;
		end if;
	end process;

	seg_com <= ("01111111" ror digit) xor repeat(common_anode, 8); -- rotates '0' because common cathode
	-- get the digit, then look up from table, then or the dot segment (both LUT and dot port can control the dot segment)
	seg_led <= (lut(character'pos(data(digit + 1))) or (0 to 6 => '0', 7 => dot(digit))) xor repeat(common_anode, 8);

end arch;

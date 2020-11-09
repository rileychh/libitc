library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;

entity seg is
	port (
		-- system
		clk, rst_n : in std_logic;
		-- seg
		seg_1, seg_2, seg_s : out byte_be_t; -- abcdefgp * 2, seg2_s1 ~ seg1_s4
		-- use logic
		data : in string(1 to 8); -- string type only allow positive range
		dot  : in byte_be_t       -- dots are individually controlled
	);
end seg;

architecture arch of seg is

	-- decoder look up table
	type lut_t is array(0 to 2 ** 7 - 1) of byte_be_t;
	constant lut : lut_t := (
		-- HACK add additional characters between 0 to 31
		x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00",
		x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00",
		-- ASCII printable characters (SPC to DEL)
		x"00", x"61", x"44", x"7e", x"b6", x"4b", x"62", x"04", x"94", x"d0", x"84", x"0e", x"08", x"02", x"01", x"4a",
		x"fc", x"60", x"da", x"f2", x"66", x"b6", x"be", x"e0", x"fe", x"f6", x"90", x"b0", x"86", x"12", x"c2", x"cb",
		x"fa", x"ee", x"3e", x"9c", x"7a", x"9e", x"8e", x"bc", x"6e", x"0c", x"78", x"ae", x"1c", x"a8", x"ec", x"fc",
		x"ce", x"d6", x"cc", x"b6", x"1e", x"7c", x"7c", x"54", x"6e", x"76", x"da", x"9c", x"26", x"f0", x"c4", x"10",
		x"40", x"fa", x"3e", x"1a", x"7a", x"de", x"8e", x"f6", x"2e", x"08", x"30", x"ae", x"0c", x"28", x"2a", x"3a",
		x"ce", x"e6", x"0a", x"b6", x"1e", x"38", x"38", x"28", x"6e", x"76", x"da", x"62", x"0c", x"0e", x"80", x"00"
	);

	-- output wire
	signal seg_i : byte_be_t;

	signal clk_scan : std_logic;
	signal digit : integer range 0 to 7;

begin

	clk_inst : entity work.clk(arch)
		generic map(
			freq => 10_000_000
		)
		port map(
			clk_in  => clk,
			rst_n   => rst_n,
			clk_out => clk_scan
		);

	-- both outputs are the same
	seg_1 <= seg_i;
	seg_2 <= seg_i;

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

	seg_s <= "01111111" ror digit; -- rotates '0' because common cathode
	seg_i(0 to 6) <= lut(character'pos(data(digit + 1)))(0 to 6); -- get the digit, then look up from table
	seg_i(7) <= dot(digit); -- rightmost bit is the dot segment

end arch;

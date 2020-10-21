library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package seg_p is
	component seg
		port (
			-- seg
			seg_1, seg_2 : out unsigned(7 downto 0); -- abcdefgp * 2
			seg_s        : out unsigned(0 to 7);     -- seg2_s1 ~ seg1_s4
			-- internal
			clk  : in std_logic;       -- 1kHz
			data : in string(1 to 8);  -- string type only allow positive range
			dot  : in unsigned(0 to 7) -- dots are individually controlled
		);
	end component;

	function to_character(n : integer range 0 to 15) return character;
	function to_character(n : unsigned(3 downto 0)) return character;

	-- converts an number into bcd
	-- n: the number
	-- n_width: number of bits needed to represent n
	-- bcd_len: return length in nibbles (1 digit == 4 bits)
	function to_bcd(n, n_width, bcd_len : integer) return unsigned;
	function to_bcd(n : unsigned; n_width, bcd_len : integer) return unsigned;
end package;

package body seg_p is
	function to_character(n : integer range 0 to 15) return character is begin
		if n < 10 then -- n is decimal
			return character'val(n + character'pos('0'));
		else -- n is hexadecimal
			return character'val(n - 10 + character'pos('A'));
		end if;
	end function;

	function to_character(n : unsigned(3 downto 0)) return character is begin
		if n < 10 then -- n is decimal
			return character'val(to_integer(n) + character'pos('0'));
		else -- n is hexadecimal
			return character'val(to_integer(n - 10) + character'pos('A'));
		end if;
	end function;

	function to_bcd(n, n_width, bcd_len : integer) return unsigned is

		variable bin : unsigned(n_width - 1 downto 0) := to_unsigned(n, n_width);
		variable bcd : unsigned(bcd_len * 4 - 1 downto 0) := (others => '0');
		variable j : integer;

	begin

		-- convert binary to BCD
		for i in 0 to n_width - 1 loop
			-- check if any nibble (bcd digit) is more then 4
			-- for (j = 0; j < bcd_len - 4; j += 4)
			-- j is the bit count, 
			j := 0;
			while j < (bcd_len - 1) * 4 loop
				if bcd(j + 3 downto j) > 4 then
					bcd(j + 3 downto j) := bcd(j + 3 downto j) + 3; -- add 3 to the nibble
				end if;

				j := j + 4;
			end loop;

			--   shift
			--  <------
			-- bcd & bin
			bcd := bcd sll 1;
			bcd(bcd'right) := bin(bin'left);
			bin := bin sll 1;
		end loop;

		return bcd;

	end function;

	function to_bcd(n : unsigned; n_width, bcd_len : integer) return unsigned is

		variable bin : unsigned(n'range) := n;
		variable bcd : unsigned(bcd_len * 4 - 1 downto 0) := (others => '0');
		variable j : integer;

	begin

		-- convert binary to BCD
		for i in 0 to n_width - 1 loop
			-- check if any nibble (bcd digit) is more then 4
			-- for (j = 0; j < bcd_len - 4; j += 4)
			-- j is the bit count, 
			j := 0;
			while j < (bcd_len - 1) * 4 loop
				if bcd(j + 3 downto j) > 4 then
					bcd(j + 3 downto j) := bcd(j + 3 downto j) + 3; -- add 3 to the nibble
				end if;

				j := j + 4;
			end loop;

			--   shift
			--  <------
			-- bcd & bin
			bcd := bcd sll 1;
			bcd(bcd'right) := bin(bin'left);
			bin := bin sll 1;
		end loop;

		return bcd;

	end function;
end package body;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity seg is
	port (
		-- seg
		seg_1, seg_2 : out unsigned(7 downto 0); -- abcdefgp * 2
		seg_s        : out unsigned(0 to 7);     -- seg2_s1 ~ seg1_s4
		-- internal
		clk  : in std_logic;       -- 1kHz
		data : in string(1 to 8);  -- string type only allow positive range
		dot  : in unsigned(0 to 7) -- dots are individually controlled
	);
end seg;

architecture arch of seg is

	type lut_t is array(0 to 127) of unsigned(7 downto 0);
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
	signal led : unsigned(7 downto 0);

	-- scan count
	signal scan_cnt : integer range 0 to 7;

begin

	-- both outputs are the same
	seg_1 <= led;
	seg_2 <= led;

	process (clk) begin
		if rising_edge(clk) then
			seg_s <= "01111111" ror scan_cnt; -- rotates '0' because common cathode
			led <= lut(character'pos(data(scan_cnt + 1))); -- get the digit, then filter though look-up table
			if dot(scan_cnt) = '1' then -- current segment should light up dot
				led(0) <= '1'; -- led(0) is the dot segment
			end if;
			scan_cnt <= scan_cnt + 1;
		end if;
	end process;

end arch;
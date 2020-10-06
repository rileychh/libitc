library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package bcd_p is
	component to_bcd
		generic (
			bin_width : integer := 8;
			digit_len : integer := 3
		);

		port (
			-- internal
			bin : in unsigned(bin_width - 1 downto 0);
			bcd : out unsigned(digit_len * 4 - 1 downto 0)
		);
	end component;
end package;

--
-- to_bcd
-- using double dabble algorithm
-- https://en.wikipedia.org/wiki/Double_dabble
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.bcd_p.all;

entity to_bcd is
	generic (
		bin_width : integer := 8;
		digit_len : integer := 3
	);

	port (
		-- internal
		bin : in unsigned(bin_width - 1 downto 0);
		bcd : out unsigned(digit_len * 4 - 1 downto 0)
	);
end to_bcd;

architecture arch of to_bcd is

begin

	process (bin)

		variable bin_reg : unsigned(bin_width - 1 downto 0);
		variable bcd_reg : unsigned(digit_len * 4 - 1 downto 0);
		variable j : integer;

	begin

		bin_reg := bin;
		bcd_reg := (others => '0');

		-- convert binary to BCD
		for i in 0 to bin_width - 1 loop
			-- check if any nibble (bcd digit) is more then 4
			-- for (j = 0; j < digit_len - 4; j += 4)
			-- j is the bit count, 
			j := 0;
			while j < (digit_len - 1) * 4 loop
				if bcd_reg(j + 3 downto j) > 4 then
					bcd_reg(j + 3 downto j) := bcd_reg(j + 3 downto j) + 3; -- add 3 to the nibble
				end if;

				j := j + 4;
			end loop;

			--       shift
			--      <------
			-- bcd_reg & bin_reg
			bcd_reg := bcd_reg sll 1;
			bcd_reg(bcd_reg'right) := bin_reg(bin_reg'left);
			bin_reg := bin_reg sll 1;
		end loop;

		bcd <= bcd_reg;

	end process;

end arch;
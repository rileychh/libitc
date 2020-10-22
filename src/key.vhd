library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package key_p is
	component dbnce
		generic (
			clk_cnt : integer := 2 -- wait for this amount of cycles
		);

		port (
			-- user logic
			clk       : in std_logic;
			dbnce_in  : in std_logic;
			dbnce_out : out std_logic
		);
	end component;

	component key
		port (
			-- key
			key_col : out unsigned(0 to 3);
			key_row : in unsigned(0 to 3);
			-- system
			clk : in std_logic;
			-- user logic
			int     : out std_logic; -- '1' if something is pressed, debounced
			pressed : out integer range 0 to 15
		);
	end component;
end package;

--
-- dbnce
-- push button debouncer module
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dbnce is
	generic (
		clk_cnt : integer := 2 -- wait for this amount of cycles
	);

	port (
		-- user logic
		clk       : in std_logic;
		dbnce_in  : in std_logic;
		dbnce_out : out std_logic
	);
end dbnce;

architecture arch of dbnce is

	signal cnt : integer range 0 to clk_cnt - 1;

begin

	process (clk) begin
		if rising_edge(clk) then
			if dbnce_in = '1' then
				if cnt = clk_cnt - 1 then
					dbnce_out <= '1';
				else
					cnt <= cnt + 1;
				end if;
			else
				dbnce_out <= '0';
				cnt <= 0;
			end if;
		end if;
	end process;

end arch;

--
-- key
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.key_p.all;
use work.clk_p.all;

entity key is
	port (
		-- key
		key_col : out unsigned(0 to 3);
		key_row : in unsigned(0 to 3);
		-- system
		clk : in std_logic;
		-- user logic
		int     : out std_logic; -- '1' if something is pressed, debounced
		pressed : out integer range 0 to 15
	);
end key;

architecture arch of key is

	signal scan_clk : std_logic;
	signal col_cnt : integer range 0 to 3; -- column count, for shifting key_col
	signal int_reg : std_logic;

begin

	dbnce_inst : dbnce generic map(40) port map(clk, int_reg, int);

	clk_inst : entity work.clk(arch)
		generic map(
			freq => 1_000
		)
		port map(
			clk_in  => clk,
			rst     => '1',
			clk_out => scan_clk
		);

	process (clk) begin
		if rising_edge(clk) then
			if key_row = "1111" then -- if nothing is pressed
				-- cycle '0' between columns
				-- HACK: why start at "0111" is wrong?
				key_col <= "1011" ror col_cnt;
			end if;

			int_reg <= '1';

			case key_row is
				when "0111" => -- 0, 4, 8, c
					pressed <= col_cnt * 4;
				when "1011" => -- 1, 5, 9, d
					pressed <= col_cnt * 4 + 1;
				when "1101" => -- 2, 6, a, e
					pressed <= col_cnt * 4 + 2;
				when "1110" => -- 3, 7, b, f
					pressed <= col_cnt * 4 + 3;
				when others =>
					int_reg <= '0';
			end case;

			col_cnt <= col_cnt + 1;
		end if;
	end process;

end arch;
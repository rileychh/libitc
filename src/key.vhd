library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package key_p is
	component dbnce
		generic (
			clk_cnt : integer := 2 -- wait for this amount of cycles
		);

		port (
			-- internal
			dbnce_clk : in std_logic;
			dbnce_in  : in std_logic;
			dbnce_out : out std_logic
		);
	end component;

	component key
		port (
			-- key
			key_col : out unsigned(0 to 3);
			key_row : in unsigned(0 to 3);
			-- internal
			key_clk     : in std_logic;  -- 1kHz
			key_int     : out std_logic; -- '1' if something is pressed, debounced
			key_pressed : out integer range 0 to 15
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
		-- internal
		dbnce_clk : in std_logic;
		dbnce_in  : in std_logic;
		dbnce_out : out std_logic
	);
end dbnce;

architecture arch of dbnce is

	signal cnt : integer range 0 to clk_cnt - 1;

begin

	process (dbnce_clk) begin

		if rising_edge(dbnce_clk) then
			if dbnce_in = '1' then
				if cnt = cnt'high then
					dbnce_out <= '1';
				else
					cnt <= cnt + 1;
				end if;
			else
				dbnce_out <= '0';
				cnt       <= 0;
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

entity key is
	port (
		-- key
		key_col : out unsigned(0 to 3);
		key_row : in unsigned(0 to 3);
		-- internal
		key_clk     : in std_logic;  -- 1kHz
		key_int     : out std_logic; -- '1' if something is pressed, debounced
		key_pressed : out integer range 0 to 15
	);
end key;

architecture arch of key is

	signal col_cnt : integer range 0 to 3; -- column count, for shifting key_col
	signal int     : std_logic;

begin

	dbnce_inst : dbnce generic map(40) port map(key_clk, int, key_int);
	-- key_int <= int;

	process (key_clk) begin 
		if rising_edge(key_clk) then
			if key_row = "1111" then -- if nothing is pressed
				-- cycle '0' between columns
				-- TODO: why start at "0111" is wrong?
				key_col <= "1011" ror col_cnt;
			end if;

			int <= '1';

			case key_row is
				when "0111" => -- 0, 4, 8, c
					key_pressed <= col_cnt * 4;
				when "1011" => -- 1, 5, 9, d
					key_pressed <= col_cnt * 4 + 1;
				when "1101" => -- 2, 6, a, e
					key_pressed <= col_cnt * 4 + 2;
				when "1110" => -- 3, 7, b, f
					key_pressed <= col_cnt * 4 + 3;
				when others =>
					int <= '0';
			end case;

			col_cnt <= col_cnt + 1;
		end if; 
	end process;

end arch;
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;

entity dot is
	port (
		-- system
		clk, rst_n : in std_logic;
		-- dot
		dot_r, dot_g, dot_s : out byte_be_t;
		-- user logic
		data_r, data_g : in bytes_be_t(0 to 7)
	);
end dot;

architecture arch of dot is

	signal clk_scan : std_logic;
	signal row : integer range 0 to 7;

begin

	clk_inst : entity work.clk(arch)
		generic map(
			freq => 1_000_000
		)
		port map(
			clk_in  => clk,
			rst_n   => rst_n,
			clk_out => clk_scan
		);

	process (clk_scan, rst_n) begin
		if rst_n = '0' then
			row <= 0;
		elsif rising_edge(clk_scan) then
			if row = row'high then
				row <= 0;
			else
				row <= row + 1;
			end if;
		end if;
	end process;

	dot_s <= "01111111" ror row; -- rotates '0' because common cathode
	dot_r <= data_r(row);
	dot_g <= data_g(row);

end arch;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;

entity key_test is

	port (
		-- sys
		clk, rst_n : in std_logic;
		-- key
		key_row : in nibble_be_t;
		key_col : out nibble_be_t;
		-- seg
		seg_1, seg_2, seg_s : out byte_be_t; -- abcdefgp * 2, seg2_s1 ~ seg1_s4
		-- dbg
		dbg_a, dbg_b : out byte_be_t
	);

end key_test;

architecture arch of key_test is

	signal pressed : std_logic;
	signal key : integer range 0 to 15;
	signal buf : string(1 to 8); -- keyboard input buffer (stores text)

begin

	dbg_a <= (0 => pressed, others => '0');
	dbg_b(0 to 3) <= reverse(to_unsigned(key, 4));
	dbg_b(4 to 7) <= (others => '0');

	key_inst : entity work.key(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			key_row => key_row,
			key_col => key_col,
			pressed => pressed,
			key     => key
		);

	seg_inst : entity work.seg(arch)
		port map(
			clk   => clk,
			rst_n => rst_n,
			seg_1 => seg_1,
			seg_2 => seg_2,
			seg_s => seg_s,
			data  => buf,
			dot => (others => '0')
		);

	process (all) begin
		if rst_n = '0' then
			buf <= (others => ' ');
		elsif rising_edge(pressed) then
			-- shift key_pressed into buffer from right
			-- e.g. buf = "12345678", pressed 2 => buf = "23456782"
			buf <= buf(2 to 8) & to_string(key, 15, 16, 1)(1);
		end if;
	end process;
end arch;
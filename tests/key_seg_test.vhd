library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.clk_p.all;
use work.seg_p.all;
use work.key_p.all;

entity key_seg_test is

	port (
		-- sys
		sys_clk, sys_rst : in std_logic;
		-- key
		key_col : out unsigned(0 to 3);
		key_row : in unsigned(0 to 3);
		-- seg
		seg_1, seg_2 : out unsigned(7 downto 0); -- abcdefgp * 2
		seg_s        : out unsigned(0 to 7)      -- seg2_s1 ~ seg1_s4
	);

end key_seg_test;

architecture arch of key_seg_test is

	signal key_int : std_logic;
	signal key_pressed : integer range 0 to 15;
	signal in_buf : string(1 to 8); -- keyboard input buffer (stores text)

begin

	seg_inst : entity work.seg(arch)
		port map(
			seg_1 => seg_1,
			seg_2 => seg_2,
			seg_s => seg_s,
			clk   => sys_clk,
			data  => in_buf,
			dot => (others => '0')
		);

	key_inst : entity work.key(arch)
		port map(
			key_col => key_col,
			key_row => key_row,
			clk     => sys_clk,
			int     => key_int,
			pressed => key_pressed
		);

	process (key_int, sys_rst) begin
		if sys_rst = '0' then
			in_buf <= (others => ' ');
		elsif rising_edge(key_int) then
			-- shift key_pressed into in_buf from right
			-- e.g. in_buf = "12345678", pressed 2 => in_buf := "23456782"
			in_buf <= in_buf(2 to 8) & to_character(key_pressed);
		end if;
	end process;

end arch;
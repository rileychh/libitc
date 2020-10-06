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
		seg_1, seg_2, seg_s : out unsigned(7 downto 0); -- abcdefgp * 2, seg2_s1 ~ seg1_s4
		-- debug
		dbg_key_int : out std_logic;
		dbg_clk_1k  : out std_logic
	);

end key_seg_test;

architecture arch of key_seg_test is

	signal clk_1k : std_logic;
	signal key_int : std_logic;
	signal key_pressed : integer range 0 to 15;
	signal in_buf : seg_data_t := (others => 0); -- keyboard input buffer (stores text)

begin

	dbg_key_int <= key_int;
	dbg_clk_1k <= clk_1k;

	clk_sys_inst : entity work.clk_sys(arch)
		generic map(
			clk_out_freq => 1000
		)
		port map(
			sys_clk => sys_clk,
			sys_rst => sys_rst,
			clk_out => clk_1k
		);

	seg_inst : entity work.seg(arch)
		port map(
			seg_1    => seg_1,
			seg_2    => seg_2,
			seg_s    => seg_s,
			seg_clk  => clk_1k,
			seg_ena  => '1',
			seg_data => in_buf
		);

	key_inst : entity work.key(arch)
		port map(
			key_col     => key_col,
			key_row     => key_row,
			key_clk     => clk_1k,
			key_int     => key_int,
			key_pressed => key_pressed
		);

	process (sys_rst, key_int)

	begin

		if sys_rst = '0' then
			in_buf <= (others => 0);
		elsif rising_edge(key_int) then
			-- shift key_pressed into in_buf from right
			-- e.g. in_buf = "12345678", pressed 2 => in_buf := "23456782"
			in_buf <= in_buf(1 to 7) & key_pressed;
		end if;

	end process;

end arch;
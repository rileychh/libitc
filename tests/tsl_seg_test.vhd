library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.clk_p.all;
use work.seg_p.all;
use work.tsl_p.all;
use work.dot_p.all;

entity tsl_seg_test is
	port (
		-- sys
		sys_clk, sys_rst : in std_logic; -- rising edge clock, low reset
		-- seg
		seg_1, seg_2 : out unsigned(7 downto 0); -- abcdefgp * 2
		seg_s        : out unsigned(0 to 7);     -- seg2_s1 ~ seg1_s4
		-- dot
		dot_r, dot_g, dot_s : out unsigned(0 to 7);
		-- tsl
		tsl_scl, tsl_sda : inout std_logic
	);
end tsl_seg_test;

architecture arch of tsl_seg_test is

	signal clk_i2c, clk_1k : std_logic;
	signal tsl_lux : integer range 0 to 40000;
	signal seg_data : string(1 to 8);
	signal dot_data : dot_data_t;
	signal dbg_i2c_state : unsigned(3 downto 0);
	signal dbg_i2c_busy : std_logic;
	signal dbg_i2c_rx : unsigned(7 downto 0);
	signal dbg_i2c_tx : unsigned(7 downto 0);
	signal dbg_tsl_state : unsigned(3 downto 0);
	signal dbg_tsl_step  : unsigned(3 downto 0);
	signal dbg_tsl_data : unsigned(31 downto 0);

begin

	clk_sys_inst_i2c : entity work.clk_sys(arch)
		generic map(
			clk_out_freq => 10
		)
		port map(
			sys_clk => sys_clk,
			sys_rst => sys_rst,
			clk_out => clk_i2c
		);

	clk_sys_inst_1k : entity work.clk_sys(arch)
		generic map(
			clk_out_freq => 1_000
		)
		port map(
			sys_clk => sys_clk,
			sys_rst => sys_rst,
			clk_out => clk_1k
		);

	tsl_inst : entity work.tsl(arch)
		port map(
			tsl_scl       => tsl_scl,
			tsl_sda       => tsl_sda,
			clk           => clk_i2c,
			rst           => sys_rst,
			lux           => tsl_lux,
			dbg_i2c_state => dbg_i2c_state,
			dbg_i2c_busy  => dbg_i2c_busy,
			dbg_i2c_rx    => dbg_i2c_rx,
			dbg_i2c_tx    => dbg_i2c_tx,
			dbg_tsl_state => dbg_tsl_state,
			dbg_tsl_step  => dbg_tsl_step,
			dbg_data      => dbg_tsl_data
		);

	seg_inst : entity work.seg(arch)
		port map(
			seg_1 => seg_1,
			seg_2 => seg_2,
			seg_s => seg_s,
			clk   => clk_1k,
			data  => seg_data,
			dot => (7 => dbg_i2c_busy, others => '0')
		);
	seg_map : for i in 0 to 3 generate
		seg_data(3 - i + 1) <= to_character(to_bcd(tsl_lux, 13, 4)(i * 4 + 3 downto i * 4)); -- tsl_lux
	end generate seg_map;
	seg_data(5) <= ' ';
	seg_data(6) <= to_character(dbg_tsl_state);
	seg_data(7) <= to_character(dbg_tsl_step);
	seg_data(8) <= to_character(dbg_i2c_state);

	dot_inst : entity work.dot(arch)
		port map(
			dot_r  => dot_r,
			dot_g  => dot_g,
			dot_s  => dot_s,
			clk    => clk_1k,
			data_r => dot_data,
			data_g => dot_zeros
		);
	dot_map : for i in 0 to 3 generate
		dot_data(3 - i) <= dbg_tsl_data(i * 8 + 7 downto i * 8);
	end generate dot_map;
	dot_data(4) <= dbg_i2c_rx;
	dot_data(5) <= dbg_i2c_tx;
	dot_data(6 to 7) <= (others => (others => '0'));

end arch;
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;

entity mot_test is
	port (
		clk     : in std_logic;
		rst_n   : in std_logic;
		sw      : in u8r_t;
		mot_ch  : out u2r_t;
		mot_ena : out std_logic
	);
end mot_test;

architecture arch of mot_test is
	signal dir, ena : std_logic;
	signal speed : integer range 0 to 100;
	signal load, msec : i32_t;
begin
	mot_inst : entity work.mot(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			mot_ch  => mot_ch,
			mot_ena => mot_ena,
			dir     => dir,
			speed   => speed
		);
	timer_inst : entity work.timer(arch)
		port map(
			clk   => clk,
			rst_n => rst_n,
			ena   => ena,
			load  => load,
			msec  => msec
		);
	process (clk, rst_n)
	begin
		if rst_n = '0' then
			dir <= '0';
			speed <= 0;
			load <= 0;
			ena <= '0';
		elsif rising_edge(clk) then
			speed <= 100;
			dir <= '0';
		end if;
	end process;
end arch;

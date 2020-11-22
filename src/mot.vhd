library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;

entity mot is
	port (
		-- system
		clk, rst_n : in std_logic;
		-- mot
		mot_ch  : out u2r_t;
		mot_ena : out std_logic;
		-- user logic
		dir   : in std_logic;             -- direction of motor
		speed : in integer range 0 to 100 -- speed of motor
	);
end mot;

architecture arch of mot is

	type sqrt_t is array (0 to 100) of integer range 0 to 100;
	constant sqrt : sqrt_t := (
		0, 10, 14, 17, 20, 22, 24, 26, 28, 30,
		31, 33, 34, 36, 37, 38, 40, 41, 42, 43,
		44, 45, 46, 47, 48, 50, 50, 51, 52, 53,
		54, 55, 56, 57, 58, 59, 60, 60, 61, 62,
		63, 64, 64, 65, 66, 67, 67, 68, 69, 70,
		70, 71, 72, 72, 73, 74, 74, 75, 76, 76,
		77, 78, 78, 79, 80, 80, 81, 81, 82, 83,
		83, 84, 84, 85, 86, 86, 87, 87, 88, 88,
		89, 90, 90, 91, 91, 92, 92, 93, 93, 94,
		94, 95, 95, 96, 96, 97, 97, 98, 98, 99, 100
	);

begin

	mot_ch(0) <= dir;
	mot_ch(1) <= not dir;

	pwm_inst : entity work.pwm(arch)
		generic map(
			pwm_freq => 100_000
		)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			duty    => sqrt(speed),
			pwm_out => mot_ena
		);

end arch;

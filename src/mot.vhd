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
		dir   : in std_logic; -- direction of motor
		speed : in i8_t       -- speed of motor
	);
end mot;

architecture arch of mot is

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

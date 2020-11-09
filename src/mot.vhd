library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;

entity mot is
	generic (
		speed_res : integer := 10
	);

	port (
		-- system
		clk, rst_n : in std_logic;
		-- mot
		mot_ch  : out std_logic_vector(0 to 1);
		mot_ena : out std_logic;
		-- user logic
		dir   : in std_logic;                       -- direction of motor
		speed : in integer range 0 to speed_res - 1 -- speed of motor
	);
end mot;

architecture arch of mot is

begin

	mot_ch(0) <= dir;
	mot_ch(1) <= not dir;

	pwm_inst : entity work.pwm(arch)
		generic map(
			pwm_freq => 10_000,
			duty_res => speed_res
		)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			duty    => speed,
			pwm_out => mot_ena
		);

end arch;

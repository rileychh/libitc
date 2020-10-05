-- PWM test

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.clk_p.all;
use work.pwm_p.all;

entity pwm_test is

	port (
		-- sys
		sys_clk : in std_logic;
		-- special
		pwm_out : out std_logic
	);

end pwm_test;

architecture arch of pwm_test is

	signal clk      : std_logic;
	signal duty_cnt : integer range 0 to 99;

begin

	uclk : clk_sys
	generic map(10)
	port map(sys_clk, '0', clk);

	upwm : pwm
	generic map(100_000, 100)
	port map(sys_clk, duty_cnt, pwm_out);

	process (clk)

	begin

		if rising_edge(clk) then
			duty_cnt <= duty_cnt + 1;
		end if;

	end process;

end arch;
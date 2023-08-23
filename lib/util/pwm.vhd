-- pwm.vhd
-- component for generating single phase PWM signals

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;

entity pwm is
	generic (
		pwm_freq : integer := 100_000 -- PWM switching frequency in Hz
	);

	port (
		-- system
		clk, rst_n : in std_logic; -- system clock
		-- user logic
		duty    : in integer range 0 to 100; -- duty cycle
		pwm_out : out std_logic              -- pwm output
	);
end pwm;

architecture arch of pwm is

	constant period : integer := sys_clk_freq / pwm_freq; -- number of clocks in one pwm period
	signal high_period : integer range 0 to period := 0; -- number of clocks the output should be high
	signal cnt : integer range 0 to period - 1 := 0; -- period counter

begin

	process (clk, rst_n) begin -- counter
		if rst_n = '0' then
			cnt <= 0;
		elsif rising_edge(clk) then
			if cnt = cnt'high then
				cnt <= 0;
			else
				cnt <= cnt + 1;
			end if;
		end if;
	end process;

	high_period <= period * duty / 100;
	pwm_out <= '1' when cnt < high_period else '0';

end arch;

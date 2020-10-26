-- pwm.vhd
-- component for generating single phase PWM signals

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package pwm_p is
	component pwm
		generic (
			pwm_freq : integer := 100_000; -- PWM switching frequency in Hz
			duty_res : integer := 100      -- resolution setting of the duty cycle
		);

		port (
			-- system
			clk : in std_logic; -- system clock
			-- user logic
			duty    : in integer range 0 to duty_res - 1; -- duty cycle
			pwm_out : out std_logic                       -- pwm output
		);
	end component;
end package;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.clk_p.all; -- for sys_clk_freq constant

entity pwm is
	generic (
		pwm_freq : integer := 100_000; -- PWM switching frequency in Hz
		duty_res : integer := 100      -- resolution setting of the duty cycle
	);

	port (
		-- system
		clk : in std_logic; -- system clock
		-- user logic
		duty    : in integer range 0 to duty_res - 1; -- duty cycle
		pwm_out : out std_logic                       -- pwm output
	);
end pwm;

architecture arch of pwm is

	constant period : integer := sys_clk_freq / pwm_freq; -- number of clocks in one pwm period
	signal cnt : integer range 0 to period - 1 := 0; -- period counter
	signal high_period : integer range 0 to period - 1 := 0; -- number of clocks in 1/2 duty cycle

begin

	process (clk) begin -- counter
		if rising_edge(clk) then
			if cnt = cnt'high then
				cnt <= 0;
			else
				cnt <= cnt + 1;
			end if;
		end if;
	end process;

	high_period <= period * duty / (duty_res - 1);
	pwm_out <= '1' when cnt < high_period else '0';

end arch;
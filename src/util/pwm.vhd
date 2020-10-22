-- pwm.vhd
-- component for generating single phase PWM signals
-- https://www.digikey.com/eewiki/pages/viewpage.action?pageId=20939345

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
			-- internal
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
		clk : in std_logic;                       -- system clock
		duty    : in integer range 0 to duty_res - 1; -- duty cycle
		pwm_out : out std_logic                       -- pwm output
	);
end pwm;

architecture arch of pwm is

	constant period : integer := sys_clk_freq / pwm_freq; -- number of clocks in one pwm period
	signal cnt : integer range 0 to period - 1 := 0; -- period counter
	signal half_duty : integer range 0 to period / 2 := 0; -- number of clocks in 1/2 duty cycle

begin

	process (clk) begin
		if rising_edge(clk) then -- rising system clock edge
			half_duty <= duty * period / (duty_res - 1); -- determine clocks in 1/2 duty cycle

			cnt <= cnt + 1; --increment counter

			-- control outputs
			if cnt = half_duty then -- phase's falling edge reached
				pwm_out <= '0'; -- deassert the pwm output
			elsif cnt = period - half_duty then -- phase's rising edge reached
				pwm_out <= '1'; -- assert the pwm output
			end if; 
		end if;
	end process;

end arch;
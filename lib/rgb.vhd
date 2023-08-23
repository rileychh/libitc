library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;

entity rgb is
	port (
		-- system
		clk, rst_n : in std_logic;
		-- rgb
		rgb : out std_logic_vector(0 to 2);
		-- user logic
		color : in l_px_t -- format: 0xRGB
	);
end rgb;

architecture arch of rgb is

begin

	pwm_gen : for i in 0 to 2 generate
		pwm_inst : entity work.pwm(arch)
			generic map(
				-- higher means less LCs, but LED won't turn on if too high
				-- 3125000Hz (max for 4-bit color) is tested and working
				pwm_freq => sys_clk_freq / 2 ** 8
			)
			port map(
				clk     => clk,
				rst_n   => rst_n,
				duty    => to_integer(color((2 - i) * 8 + 7 downto (2 - i) * 8)) * 100 / 16,
				pwm_out => rgb(i)
			);
	end generate pwm_gen;

end arch;

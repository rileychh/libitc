library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.clk_p.all;

entity rgb is
	port (
		-- system
		clk : in std_logic;
		-- rgb
		rgb_r, rgb_g, rgb_b : out std_logic;
		-- user logic
		color : in unsigned(11 downto 0) -- format: 0xRGB (4-bit color)
	);
end rgb;

architecture arch of rgb is

	-- higher means less LCs, but LED won't turn on if too high
	-- 3125000Hz (max for 4-bit color) is tested and working
	constant pwm_freq : integer := sys_clk_freq / 2 ** 4;

begin

	pwm_inst_r : entity work.pwm(arch)
		generic map(
			pwm_freq => pwm_freq,
			duty_res => 2 ** 4
		)
		port map(
			clk     => clk,
			duty    => to_integer(color(11 downto 8)),
			pwm_out => rgb_r
		);

	pwm_inst_g : entity work.pwm(arch)
		generic map(
			pwm_freq => pwm_freq,
			duty_res => 2 ** 4
		)
		port map(
			clk     => clk,
			duty    => to_integer(color(7 downto 4)),
			pwm_out => rgb_g
		);

	pwm_inst_b : entity work.pwm(arch)
		generic map(
			pwm_freq => pwm_freq,
			duty_res => 2 ** 4
		)
		port map(
			clk     => clk,
			duty    => to_integer(color(3 downto 0)),
			pwm_out => rgb_b
		);

end arch;
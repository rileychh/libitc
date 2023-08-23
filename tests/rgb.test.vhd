-- rainbow party

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;

entity rgb_test is
	port (
		-- sys
		clk, rst_n : in std_logic; -- rising edge clock, low reset
		-- rgb
		rgb : out std_logic_vector(0 to 2)
	);
end rgb_test;

architecture arch of rgb_test is

	signal r, g, b : i8_t;
	signal color : l_px_t;
	signal color_clk : std_logic;

	type state_t is (r_to_g, g_to_b, b_to_r);
	signal state : state_t;

begin

	clk_inst : entity work.clk(arch)
		generic map(
			freq => 20
		)
		port map(
			clk_in  => clk,
			rst_n   => rst_n,
			clk_out => color_clk
		);

	rgb_inst : entity work.rgb(arch)
		port map(
			clk   => clk,
			rst_n => rst_n,
			rgb   => rgb,
			color => color
		);

	color <= to_unsigned(r, 8) & to_unsigned(g, 8) & to_unsigned(b, 8);

	process (color_clk, rst_n)
	begin
		if rst_n = '0' then
			r <= 255;
			g <= 0;
			b <= 0;
		elsif rising_edge(color_clk) then
			case state is
				when r_to_g =>
					if g = 255 then
						state <= g_to_b;
					else
						r <= r - 1;
						g <= g + 1;
					end if;

				when g_to_b =>
					if b = 255 then
						state <= b_to_r;
					else
						g <= g - 1;
						b <= b + 1;
					end if;

				when b_to_r =>
					if r = 255 then
						state <= r_to_g;
					else
						b <= b - 1;
						r <= r + 1;
					end if;
			end case;
		end if;
	end process;

end arch;

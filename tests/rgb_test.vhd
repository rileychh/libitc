library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rgb_test is
	port (
		-- sys
		clk, rst : in std_logic; -- rising edge clock, low reset
		-- rgb
		rgb_r, rgb_g, rgb_b : out std_logic
	);
end rgb_test;

architecture arch of rgb_test is

	signal r, g, b : integer range 0 to 15;
	signal color : unsigned(11 downto 0);
	signal color_clk : std_logic;

	type state_t is (r_to_g, g_to_b, b_to_r);
	signal state : state_t;

begin

	clk_inst : entity work.clk(arch)
		generic map(
			freq => 10
		)
		port map(
			clk_in  => clk,
			rst     => rst,
			clk_out => color_clk
		);

	rgb_inst : entity work.rgb(arch)
		port map(
			clk   => clk,
			rgb_r => rgb_r,
			rgb_g => rgb_g,
			rgb_b => rgb_b,
			color => color
		);

	color <= to_unsigned(r, 4) & to_unsigned(g, 4) & to_unsigned(b, 4);

	process (color_clk, rst)
	begin
		if rst = '0' then
			r <= 15;
			g <= 0;
			b <= 0;
		elsif rising_edge(color_clk) then
			case state is
				when r_to_g =>
					if g = 15 then
						state <= g_to_b;
					else
						r <= r - 1;
						g <= g + 1;
					end if;

				when g_to_b =>
					if b = 15 then
						state <= b_to_r;
					else
						g <= g - 1;
						b <= b + 1;
					end if;

				when b_to_r =>
					if r = 15 then
						state <= r_to_g;
					else
						b <= b - 1;
						r <= r + 1;
					end if;
			end case;
		end if;
	end process;

end arch;
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;

entity dot_test is
	port (
		-- sys
		clk, rst_n : in std_logic;
		-- seg
		seg_led, seg_com : out u8r_t;
		-- dot
		dot_red, dot_green, dot_com : out u8r_t;
		-- sw 
		sw : in u8r_t
	);
end dot_test;

architecture arch of dot_test is

	signal dot_data_r, dot_data_g : u8r_arr_t(0 to 7);

	signal x_pos, y_pos : integer range 0 to 7;
	signal clk_pos : std_logic;

begin

	dot_inst : entity work.dot(arch)
		port map(
			clk       => clk,
			rst_n     => rst_n,
			dot_red   => dot_red,
			dot_green => dot_green,
			dot_com   => dot_com,
			data_r    => dot_data_r,
			data_g    => dot_data_g
		);

	seg_inst : entity work.seg(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			seg_led => seg_led,
			seg_com => seg_com,
			data    => "rOW" & to_string(y_pos, y_pos'high, 10, 1) & "COL" & to_string(x_pos, x_pos'high, 10, 1),
			dot => (others => '0')
		);

	clk_inst : entity work.clk(arch)
		generic map(
			freq => 8
		)
		port map(
			clk_in  => clk,
			rst_n   => rst_n,
			clk_out => clk_pos
		);

	process (clk_pos, rst_n) begin
		if rst_n = '0' then
			x_pos <= 0;
			y_pos <= 0;
		elsif rising_edge(clk_pos) then
			if x_pos = x_pos'high then
				x_pos <= 0;
				if y_pos = y_pos'high then
					y_pos <= 0;
				else
					y_pos <= y_pos + 1;
				end if;
			else
				x_pos <= x_pos + 1;
			end if;

			dot_data_r <= (others => (others => '0'));
			dot_data_g <= (others => (others => '0'));

			if sw(0) = '1' then
				dot_data_g(y_pos)(x_pos) <= '1';
			end if;

			if sw(1) = '1' then
				dot_data_r(y_pos)(x_pos) <= '1';
			end if;
		end if;
	end process;

end arch;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;

entity dot_test is
	port (
		-- sys
		clk, rst_n : in std_logic;
		-- seg
		seg_1, seg_2, seg_s : out byte_be_t; -- abcdefgp * 2, seg2_s1 ~ seg1_s4
		-- dot
		dot_r, dot_g, dot_s : out byte_be_t;
		-- sw 
		sw : in byte_t
	);
end dot_test;

architecture arch of dot_test is

	signal dot_data_r, dot_data_g : bytes_be_t(0 to 7);

	signal x_pos, y_pos : integer range 0 to 7;
	signal clk_pos : std_logic;

begin

	dot_inst : entity work.dot(arch)
		port map(
			clk    => clk,
			rst_n  => rst_n,
			dot_r  => dot_r,
			dot_g  => dot_g,
			dot_s  => dot_s,
			data_r => dot_data_r,
			data_g => dot_data_g
		);

	seg_inst : entity work.seg(arch)
		port map(
			clk   => clk,
			rst_n => rst_n,
			seg_1 => seg_1,
			seg_2 => seg_2,
			seg_s => seg_s,
			data  => to_string(x_pos, x_pos'high, 10, 4) & to_string(y_pos, y_pos'high, 10, 4),
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
				dot_data_g(x_pos)(y_pos) <= '1';
			end if;

			if sw(1) = '1' then
				dot_data_r(x_pos)(y_pos) <= '1';
			end if;
		end if;
	end process;

end arch;

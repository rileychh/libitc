-- keyboard layout:
-- +------------------+------------+--+--+
-- | speed up         | speed down |  |  |
-- +------------------+------------+--+--+
-- | counterclockwise | clockwise  |  |  |
-- +------------------+------------+--+--+
-- |                  |            |  |  |
-- +------------------+------------+--+--+
-- | change motor     | OK         |  |  |
-- +------------------+------------+--+--+

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;

entity mot_test is
	port (
		-- sys
		clk, rst_n : in std_logic;
		-- seg
		seg_1, seg_2, seg_s : out byte_be_t; -- abcdefgp * 2, seg2_s1 ~ seg1_s4
		-- key
		key_row : in nibble_be_t;
		key_col : out nibble_be_t;
		-- mot
		mot_ch  : out std_logic_vector(0 to 3);
		mot_ena : out std_logic_vector(0 to 1)
	);
end mot_test;

architecture arch of mot_test is

	signal seg : string(1 to 8);
	signal pressed : std_logic;
	signal key : integer range 0 to 15;
	signal dir : std_logic_vector(0 to 1);
	type speed_t is array (0 to 1) of integer range 0 to 9;
	signal speed : speed_t;

	signal mot_disp : integer range 0 to 1;
	signal dir_disp : std_logic_vector(0 to 1);
	signal speed_disp : speed_t;

begin

	seg_inst : entity work.seg(arch)
		port map(
			clk   => clk,
			rst_n => rst_n,
			seg_1 => seg_1,
			seg_2 => seg_2,
			seg_s => seg_s,
			data  => seg,
			dot => (others => '0')
		);

	process (all) begin
		seg(1 to 3) <= "MOt";
		seg(4) <= to_string(mot_disp, mot_disp'high, 2, 1)(1);
		if dir_disp(mot_disp) = '0' then
			seg(5 to 7) <= "CCW";
		else
			seg(5 to 7) <= " CW";
		end if;
		seg(8) <= to_string(speed_disp(mot_disp), speed_disp(mot_disp)'high, 10, 1)(1);
	end process;

	key_inst : entity work.key(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			key_row => key_row,
			key_col => key_col,
			pressed => pressed,
			key     => key
		);

	mot_gen : for i in 0 to 1 generate
		mot_inst : entity work.mot(arch)
			generic map(
				speed_res => 10
			)
			port map(
				clk     => clk,
				rst_n   => rst_n,
				mot_ch  => mot_ch(i * 2 to i * 2 + 1),
				mot_ena => mot_ena(i),
				dir     => dir(i),
				speed   => speed(i)
			);
	end generate mot_gen;

	process (pressed, rst_n) begin
		if rst_n = '0' then
			mot_disp <= 0;
			dir <= (others => '1');
			dir_disp <= (others => '1');
			speed <= (others => 0);
			speed_disp <= (others => 0);
		elsif rising_edge(pressed) then
			case key is
				when 0 => -- speed up
					if speed_disp(mot_disp) < 9 then
						speed_disp(mot_disp) <= speed_disp(mot_disp) + 1;
					end if;
				when 1 => -- speed down
					if speed_disp(mot_disp) > 0 then
						speed_disp(mot_disp) <= speed_disp(mot_disp) - 1;
					end if;
				when 4 => -- counterclockwise
					dir_disp(mot_disp) <= '0';
				when 5 => -- clockwise
					dir_disp(mot_disp) <= '1';
				when 12 => -- change motor
					if mot_disp = mot_disp'high then
						mot_disp <= 0;
					else
						mot_disp <= mot_disp + 1;
					end if;
				when 13 => -- OK
					speed <= speed_disp;
					dir <= dir_disp;
				when others => null;
			end case;
		end if;
	end process;

end arch;

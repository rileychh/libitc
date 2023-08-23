library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.itc.all;

entity l_game is
	port (
		clk   : in std_logic;
		rst_n : in std_logic;

		key_row : in u4r_t;
		key_col : out u4r_t;

		seg_led : out u8r_t;
		seg_com : out u8r_t;

		dot_red   : out u8r_t;
		dot_green : out u8r_t;
		dot_com   : out u8r_t);
end l_game;

architecture arch of l_game is
	type mode is (res, choose, man, game);
	signal mode_t : mode;

	type game_m is (set, move, shoot, end_game);
	signal game_t : game_m;

	signal inter_rst : std_logic;

	signal data_r, data_g : u8r_arr_t(0 to 7);

	signal seg_data : string(1 to 8);
	signal seg_dot : u8r_t;

	signal clk1000, clk_2hz, clk_e2 : std_logic;

	signal pressed_i, key_flag : std_logic;
	signal key_data : i4_t;

	constant dot_clear : u8r_arr_t(0 to 7) := (x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00");
	constant dot_full : u8r_arr_t(0 to 7) := (x"ff", x"ff", x"ff", x"ff", x"ff", x"ff", x"ff", x"ff");
	constant dot_r : u8r_arr_t(0 to 7) := (x"41", x"42", x"44", x"48", x"7c", x"42", x"42", x"7c"); --R
	constant dot_e : u8r_arr_t(0 to 7) := (x"7e", x"40", x"40", x"7e", x"40", x"40", x"40", x"7e"); --E
	constant dot_s : u8r_arr_t(0 to 7) := (x"3c", x"42", x"02", x"04", x"38", x"40", x"42", x"3c"); --S
	constant dot_t : u8r_arr_t(0 to 7) := (x"18", x"18", x"18", x"18", x"18", x"18", x"18", x"ff"); --T
	constant dot_man_1 : u8r_arr_t(0 to 7) := (x"66", x"22", x"34", x"18", x"78", x"30", x"60", x"60");
	constant dot_man_2 : u8r_arr_t(0 to 7) := (x"42", x"62", x"34", x"5a", x"7c", x"30", x"60", x"60");
	constant dot_man_3 : u8r_arr_t(0 to 7) := (x"02", x"66", x"18", x"b2", x"7c", x"30", x"60", x"60");
	constant dot_man_4 : u8r_arr_t(0 to 7) := (x"02", x"c6", x"28", x"b0", x"64", x"78", x"c0", x"c0");
	constant dot_man_5 : u8r_arr_t(0 to 7) := (x"e2", x"26", x"3a", x"b4", x"78", x"60", x"c0", x"c0");
	constant dot_man_6 : u8r_arr_t(0 to 7) := (x"c4", x"4c", x"32", x"b4", x"78", x"60", x"c0", x"c0");
	constant dot_man_7 : u8r_arr_t(0 to 7) := (x"28", x"58", x"30", x"74", x"78", x"60", x"c0", x"c0");
	constant dot_man_8 : u8r_arr_t(0 to 7) := (x"04", x"1c", x"14", x"18", x"38", x"30", x"60", x"60");
	constant dot_man_pause : u8r_arr_t(0 to 7) := (x"66", x"3c", x"18", x"5a", x"5a", x"3c", x"18", x"18");
	constant dot_game_set_r : u8r_arr_t(0 to 7) := (x"00", x"00", x"00", x"00", x"00", x"00", x"db", x"db");
	constant dot_game_set_g : u8r_arr_t(0 to 7) := (x"e0", x"40", x"00", x"00", x"00", x"00", x"00", x"00");
begin
	dot_inst : entity work.dot(arch)
		generic map(
			common_anode => '0'
		)
		port map(
			clk       => clk,
			rst_n     => rst_n,
			dot_red   => dot_red,
			dot_green => dot_green,
			dot_com   => dot_com,
			data_r    => data_g,
			data_g    => data_r
		);
	clk_inst : entity work.clk(arch)
		generic map(
			freq => 1000
		)
		port map(
			clk_in  => clk,
			rst_n   => rst_n,
			clk_out => clk1000
		);
	clk_2hz_inst : entity work.clk(arch)
		generic map(
			freq => 2
		)
		port map(
			clk_in  => clk,
			rst_n   => rst_n,
			clk_out => clk_2hz
		);
	seg_inst : entity work.seg(arch)
		generic map(
			common_anode => '1'
		)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			seg_led => seg_led,
			seg_com => seg_com,
			data    => seg_data,
			dot => (others => '0')
		);
	key_inst : entity work.key(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			key_row => key_row,
			key_col => key_col,
			pressed => pressed_i,
			key     => key_data
		);
	edge_key_inst : entity work.edge(arch)
		port map(
			clk     => clk1000,
			rst_n   => rst_n,
			sig_in  => pressed_i,
			rising  => key_flag,
			falling => open
		);
	edge_clk_2hz_inst : entity work.edge(arch)
		port map(
			clk     => clk1000,
			rst_n   => rst_n,
			sig_in  => clk_2hz,
			rising  => clk_e2,
			falling => open
		);

	inter_rst <= '0' when (key_flag = '1') and (key_data = 12) else '1';

	process (clk1000, rst_n)
		variable fun, s_p : std_logic;
		variable count : integer;
		variable dot_x : integer range 0 to 7;
		variable dot_y : integer range 0 to 7;
		variable enemy_1 : std_logic;
		variable enemy_2 : std_logic;
		variable enemy_3 : std_logic;
	begin
		if rst_n = '0' or inter_rst = '0' then
			count := 0;
			fun := '0';
			s_p := '1';
			mode_t <= res;
		elsif rising_edge(clk1000) then
			case mode_t is
				when res =>
					data_g <= dot_clear;
					if count <= 1000 then
						data_r <= dot_r;
						count := count + 1;
					elsif count <= 2000 then
						data_r <= dot_e;
						count := count + 1;
					elsif count <= 3000 then
						data_r <= dot_s;
						count := count + 1;
					elsif count <= 4000 then
						data_r <= dot_e;
						count := count + 1;
					elsif count <= 5000 then
						data_r <= dot_t;
						count := count + 1;
					elsif count > 5000 then
						data_r <= dot_clear;
						fun := '0';
						mode_t <= choose;
					end if;
					if count <= 500 then
						seg_data <= "00000000";
					elsif count <= 1000 then
						seg_data <= "11111111";
					elsif count <= 1500 then
						seg_data <= "22222222";
					elsif count <= 2000 then
						seg_data <= "33333333";
					elsif count <= 2500 then
						seg_data <= "44444444";
					elsif count <= 3000 then
						seg_data <= "55555555";
					elsif count <= 3500 then
						seg_data <= "66666666";
					elsif count <= 4000 then
						seg_data <= "77777777";
					elsif count <= 4500 then
						seg_data <= "88888888";
					elsif count <= 5000 then
						seg_data <= "99999999";
					end if;
				when choose =>
					if key_flag = '1' and key_data = 13 then
						fun := not fun;
					end if;
					if fun = '0' then
						seg_data <= "  F1    ";
						data_g <= dot_man_1;
						data_r <= dot_clear;
						if key_flag = '1' and key_data = 14 then
							count := 0;
							seg_data <= "  F1  OK";
							mode_t <= man;
						end if;
					elsif fun = '1' then
						seg_data <= "  F2    ";
						data_r <= dot_game_set_r;
						data_g <= dot_game_set_g;
						if key_flag = '1' and key_data = 14 then
							count := 0;
							seg_data <= "  F2  OK";
							mode_t <= game;
							game_t <= set;
						end if;
					end if;
				when man =>
					if key_flag = '1' and key_data = 15 then
						s_p := not s_p;
					elsif key_flag = '1' and key_data = 3 then
						mode_t <= choose;
					end if;
					if s_p = '1' and count /= 800 then
						count := count + 1;
						data_r <= dot_clear;
					elsif s_p = '1' and count >= 800 then
						count := 0;
					end if;
					if s_p = '1' and count <= 100 then
						data_g <= dot_man_1;
					elsif s_p = '1' and count <= 200 then
						data_g <= dot_man_2;
					elsif s_p = '1' and count <= 300 then
						data_g <= dot_man_3;
					elsif s_p = '1' and count <= 400 then
						data_g <= dot_man_4;
					elsif s_p = '1' and count <= 500 then
						data_g <= dot_man_5;
					elsif s_p = '1' and count <= 600 then
						data_g <= dot_man_6;
					elsif s_p = '1' and count <= 700 then
						data_g <= dot_man_7;
					elsif s_p = '1' and count <= 800 then
						data_g <= dot_man_8;
					elsif s_p = '0' then
						data_g <= dot_clear;
						data_r <= dot_man_pause;
					end if;
				when game =>
					if key_flag = '1' and key_data = 3 then
						mode_t <= choose;
					end if;
					case game_t is
						when set =>
							data_r <= dot_game_set_r;
							data_g <= dot_game_set_g;
							dot_x := 0;
							dot_y := 0;
							enemy_1 := '1';
							enemy_2 := '1';
							enemy_3 := '1';
							game_t <= move;
						when move =>
							if key_flag = '1' then
								if key_data = 8 then
									if dot_x = 0 then
										dot_x := 0;
									else
										dot_x := dot_x - 1;
									end if;
								elsif key_data = 9 then
									game_t <= shoot;
								elsif key_data = 10 then
									if dot_x = 5 then
										dot_x := 5;
									else
										dot_x := dot_x + 1;
									end if;
								end if;
							elsif enemy_1 = '0' and enemy_2 = '0' and enemy_3 = '0' then
								game_t <= end_game;
								count := 0;
							end if;
							data_g <= (others => (others => '0'));
							data_g(0)(dot_x) <= '1';
							data_g(0)(dot_x + 1) <= '1';
							data_g(0)(dot_x + 2) <= '1';
							data_g(1)(dot_x + 1) <= '1';
						when shoot =>
							-- data_g <= (others => (others => '0'));

							-- data_g(0)(dot_x) <= '1';
							-- data_g(0)(dot_x + 1) <= '1';
							-- data_g(0)(dot_x + 2) <= '1';
							-- data_g(1)(dot_x + 1) <= '1';

							-- data_g(dot_y)(dot_x + 1) <= '1';
							-- data_r(dot_y)(dot_x + 1) <= '1';
							-- data_r(dot_y - 1)(dot_x + 1) <= '0';

							-- if clk_e2 = '1' then
							-- 	if dot_x = 1 or dot_x = 4 then
							-- 		dot_y := dot_y + 1;
							-- 		if dot_y = 7 then
							-- 			dot_y := 2;
							-- 			data_g(7)(2) <= '0';
							-- 			data_r(7)(2) <= '0';
							-- 			game_t <= move;
							-- 		end if;
							-- 	end if;
							-- end if;
							if count /= 3001 then
								count := count + 1;
							else
								count := 0;
							end if;

							if data_g(1)(1) = '1' then
								if count <= 500 then
									data_r(2)(1) <= '1';
									data_g(2)(1) <= '1';
								elsif count <= 1000 then
									data_r(2)(1) <= '0';
									data_g(2)(1) <= '0';
									data_r(3)(1) <= '1';
									data_g(3)(1) <= '1';
								elsif count <= 1500 then
									data_r(3)(1) <= '0';
									data_g(3)(1) <= '0';
									data_r(4)(1) <= '1';
									data_g(4)(1) <= '1';
								elsif count <= 2000 then
									data_r(4)(1) <= '0';
									data_g(4)(1) <= '0';
									data_r(5)(1) <= '1';
									data_g(5)(1) <= '1';
								elsif count <= 2500 then
									if enemy_1 = '1' then
										data_r(5)(1) <= '0';
										data_g(5)(1) <= '0';
										data_r(7)(0) <= '0';
										data_r(7)(1) <= '0';
										data_r(6)(0) <= '0';
										data_r(6)(1) <= '0';
										game_t <= move;
										enemy_1 := '0';
										count := 0;
									else
										data_r(5)(1) <= '0';
										data_g(5)(1) <= '0';
										data_r(6)(1) <= '1';
										data_g(6)(1) <= '1';
									end if;
								elsif count <= 3000 and enemy_1 = '0' then
									data_r(6)(1) <= '0';
									data_g(6)(1) <= '0';
									data_r(7)(1) <= '1';
									data_g(7)(1) <= '1';
								elsif count > 3000 and enemy_1 = '0' then
									data_r(7)(1) <= '0';
									data_g(7)(1) <= '0';
									count := 0;
									game_t <= move;
								end if;
							elsif data_g(1)(2) = '1' then
								if count <= 500 then
									data_r(2)(2) <= '1';
									data_g(2)(2) <= '1';
								elsif count <= 1000 then
									data_r(2)(2) <= '0';
									data_g(2)(2) <= '0';
									data_r(3)(2) <= '1';
									data_g(3)(2) <= '1';
								elsif count <= 1500 then
									data_r(3)(2) <= '0';
									data_g(3)(2) <= '0';
									data_r(4)(2) <= '1';
									data_g(4)(2) <= '1';
								elsif count <= 2000 then
									data_r(4)(2) <= '0';
									data_g(4)(2) <= '0';
									data_r(5)(2) <= '1';
									data_g(5)(2) <= '1';
								elsif count <= 2500 then
									data_r(5)(2) <= '0';
									data_g(5)(2) <= '0';
									data_r(6)(2) <= '1';
									data_g(6)(2) <= '1';
								elsif count <= 3000 then
									data_r(6)(2) <= '0';
									data_g(6)(2) <= '0';
									data_r(7)(2) <= '1';
									data_g(7)(2) <= '1';
								elsif count > 3000 then
									data_r(7)(2) <= '0';
									data_g(7)(2) <= '0';
									count := 0;
									game_t <= move;
								end if;
							elsif data_g(1)(3) = '1' then
								if count <= 500 then
									data_r(2)(3) <= '1';
									data_g(2)(3) <= '1';
								elsif count <= 1000 then
									data_r(2)(3) <= '0';
									data_g(2)(3) <= '0';
									data_r(3)(3) <= '1';
									data_g(3)(3) <= '1';
								elsif count <= 1500 then
									data_r(3)(3) <= '0';
									data_g(3)(3) <= '0';
									data_r(4)(3) <= '1';
									data_g(4)(3) <= '1';
								elsif count <= 2000 then
									data_r(4)(3) <= '0';
									data_g(4)(3) <= '0';
									data_r(5)(3) <= '1';
									data_g(5)(3) <= '1';
								elsif count <= 2500 then
									if enemy_2 = '1' then
										data_r(5)(3) <= '0';
										data_g(5)(3) <= '0';
										data_r(7)(3) <= '0';
										data_r(7)(4) <= '0';
										data_r(6)(3) <= '0';
										data_r(6)(4) <= '0';
										game_t <= move;
										enemy_2 := '0';
										count := 0;
									else
										data_r(5)(3) <= '0';
										data_g(5)(3) <= '0';
										data_r(6)(3) <= '1';
										data_g(6)(3) <= '1';
									end if;
								elsif count <= 3000 and enemy_2 = '0' then
									data_r(6)(3) <= '0';
									data_g(6)(3) <= '0';
									data_r(7)(3) <= '1';
									data_g(7)(3) <= '1';
								elsif count > 3000 and enemy_2 = '0' then
									data_r(7)(3) <= '0';
									data_g(7)(3) <= '0';
									count := 0;
									game_t <= move;
								end if;
							elsif data_g(1)(4) = '1' then
								if count <= 500 then
									data_r(2)(4) <= '1';
									data_g(2)(4) <= '1';
								elsif count <= 1000 then
									data_r(2)(4) <= '0';
									data_g(2)(4) <= '0';
									data_r(3)(4) <= '1';
									data_g(3)(4) <= '1';
								elsif count <= 1500 then
									data_r(3)(4) <= '0';
									data_g(3)(4) <= '0';
									data_r(4)(4) <= '1';
									data_g(4)(4) <= '1';
								elsif count <= 2000 then
									data_r(4)(4) <= '0';
									data_g(4)(4) <= '0';
									data_r(5)(4) <= '1';
									data_g(5)(4) <= '1';
								elsif count <= 2500 then
									if enemy_2 = '1' then
										data_r(5)(4) <= '0';
										data_g(5)(4) <= '0';
										data_r(7)(3) <= '0';
										data_r(7)(4) <= '0';
										data_r(6)(3) <= '0';
										data_r(6)(4) <= '0';
										game_t <= move;
										enemy_2 := '0';
										count := 0;
									else
										data_r(5)(4) <= '0';
										data_g(5)(4) <= '0';
										data_r(6)(4) <= '1';
										data_g(6)(4) <= '1';
									end if;
								elsif count <= 3000 and enemy_2 = '0' then
									data_r(6)(4) <= '0';
									data_g(6)(4) <= '0';
									data_r(7)(4) <= '1';
									data_g(7)(4) <= '1';
								elsif count > 3000 and enemy_2 = '0' then
									data_r(7)(4) <= '0';
									data_g(7)(4) <= '0';
									count := 0;
									game_t <= move;
								end if;
							elsif data_g(1)(5) = '1' then
								if count <= 500 then
									data_r(2)(5) <= '1';
									data_g(2)(5) <= '1';
								elsif count <= 1000 then
									data_r(2)(5) <= '0';
									data_g(2)(5) <= '0';
									data_r(3)(5) <= '1';
									data_g(3)(5) <= '1';
								elsif count <= 1500 then
									data_r(3)(5) <= '0';
									data_g(3)(5) <= '0';
									data_r(4)(5) <= '1';
									data_g(4)(5) <= '1';
								elsif count <= 2000 then
									data_r(4)(5) <= '0';
									data_g(4)(5) <= '0';
									data_r(5)(5) <= '1';
									data_g(5)(5) <= '1';
								elsif count <= 2500 then
									data_r(5)(5) <= '0';
									data_g(5)(5) <= '0';
									data_r(6)(5) <= '1';
									data_g(6)(5) <= '1';
								elsif count <= 3000 then
									data_r(6)(5) <= '0';
									data_g(6)(5) <= '0';
									data_r(7)(5) <= '1';
									data_g(7)(5) <= '1';
								elsif count > 3000 then
									data_r(7)(5) <= '0';
									data_g(7)(5) <= '0';
									count := 0;
									game_t <= move;
								end if;
							elsif data_g(1)(6) = '1' then
								if count <= 500 then
									data_r(2)(6) <= '1';
									data_g(2)(6) <= '1';
								elsif count <= 1000 then
									data_r(2)(6) <= '0';
									data_g(2)(6) <= '0';
									data_r(3)(6) <= '1';
									data_g(3)(6) <= '1';
								elsif count <= 1500 then
									data_r(3)(6) <= '0';
									data_g(3)(6) <= '0';
									data_r(4)(6) <= '1';
									data_g(4)(6) <= '1';
								elsif count <= 2000 then
									data_r(4)(6) <= '0';
									data_g(4)(6) <= '0';
									data_r(5)(6) <= '1';
									data_g(5)(6) <= '1';
								elsif count <= 2500 then
									if enemy_3 = '1' then
										data_r(5)(6) <= '0';
										data_g(5)(6) <= '0';
										data_r(7)(6) <= '0';
										data_r(7)(7) <= '0';
										data_r(6)(6) <= '0';
										data_r(6)(7) <= '0';
										game_t <= move;
										enemy_3 := '0';
										count := 0;
									else
										data_r(5)(6) <= '0';
										data_g(5)(6) <= '0';
										data_r(6)(6) <= '1';
										data_g(6)(6) <= '1';
									end if;
								elsif count <= 3000 and enemy_3 = '0' then
									data_r(6)(6) <= '0';
									data_g(6)(6) <= '0';
									data_r(7)(6) <= '1';
									data_g(7)(6) <= '1';
								elsif count > 3000 and enemy_3 = '0' then
									data_r(7)(6) <= '0';
									data_g(7)(6) <= '0';
									count := 0;
									game_t <= move;
								end if;
							end if;
						when end_game =>
							if count /= 2000 then
								seg_data <= "GAMEOVER";
								count := count + 1;
							else
								mode_t <= choose;
							end if;
					end case;
			end case;
		end if;
	end process;
end architecture;

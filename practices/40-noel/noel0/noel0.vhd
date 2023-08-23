library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.itc.all;

entity noel0 is
	port (
		clk     : in std_logic;
		rst_n   : in std_logic;
		key_row : in u4r_t;
		sw      : in std_logic_vector(0 to 1);
		key_col : out u4r_t;
		seg_led : out u8r_t;
		seg_com : out u8r_t);
end noel0;

architecture arch of noel0 is
	type mode is (m0, m1, m2, m3, m4);
	signal mode_t : mode;

	type seg_mod4 is (la, lb, ld, le);
	signal seg_m : seg_mod4;

	signal clk1000 : std_logic;
	signal k_pressed : std_logic; -- not edge pressed
	signal k_flag : std_logic;
	signal inter_rst : std_logic;

	signal cou : integer;

	signal keypad : character;

	signal seg_data : string(1 to 8);

	signal seg_dot : u8r_t;
	signal key_data : i4_t;
begin

	clk_inst : entity work.clk(arch)
		generic map(
			freq => 1000
		)
		port map(
			clk_in  => clk,
			rst_n   => rst_n,
			clk_out => clk1000
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
			dot     => seg_dot
		);

	key_inst : entity work.key(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			key_row => key_row,
			key_col => key_col,
			pressed => k_pressed,
			key     => key_data
		);

	edge_inst_key : entity work.edge(arch)
		port map(
			clk     => clk1000,
			rst_n   => rst_n,
			sig_in  => k_pressed,
			rising  => k_flag,
			falling => open
		);

	inter_rst <= '0' when (k_flag = '1') and (key_data = 12) else '1';

	process (rst_n, inter_rst)
		variable s_p : std_logic;
		variable count : integer;
		variable speed_con : integer range 1 to 2;
	begin

		if rst_n = '0' or inter_rst = '0' then
			seg_data <= "        ";
			count := 0;
			cou <= 0;
			s_p := '0';
			mode_t <= m4;
		elsif rising_edge(clk1000) then
			case mode_t is
				when m0 =>
					if count <= 500 then
						seg_data <= "S       ";
						count := count + 1;
					elsif count <= 1000 then
						seg_data <= "SI      ";
						count := count + 1;
					elsif count <= 1500 then
						seg_data <= "SIV     ";
						count := count + 1;
					elsif count <= 2000 then
						seg_data <= "SIVS    ";
						count := count + 1;
					elsif count <= 2500 then
						seg_data <= "SIVSE   ";
						count := count + 1;
					elsif count <= 3000 then
						seg_data <= "SIVSEE  ";
						count := count + 1;
					elsif count <= 3500 then
						seg_data <= " SIVSEE ";
						count := count + 1;
					elsif count <= 4000 then
						seg_data <= "  SIVSEE";
						count := count + 1;
					elsif count <= 4500 then
						seg_data <= "E  SIVSE";
						count := count + 1;
					elsif count <= 5000 then
						seg_data <= "EE  SIVS";
						count := count + 1;
					elsif count <= 5500 then
						seg_data <= "SEE  SIV";
						count := count + 1;
					elsif count <= 6000 then
						seg_data <= "VSEE  SI";
						count := count + 1;
					elsif count <= 6500 then
						seg_data <= "IVSEE  S";
						count := count + 1;
					elsif count > 6500 then
						count := 2501;
					end if;

					if k_flag = '1' and key_data = 13 and sw = "00" then
						count := 0;
						mode_t <= m0;
					elsif k_flag = '1' and key_data = 13 and sw = "01" then
						cou <= 0;
						count := 0;
						mode_t <= m1;
					elsif k_flag = '1' and key_data = 13 and sw = "10" then
						count := 0;
						speed_con := 2;
						mode_t <= m2;
					elsif k_flag = '1' and key_data = 13 and sw = "11" then
						count := 0;
						seg_data <= SOH & "       ";
						mode_t <= m3;
					end if;

				when m1 =>
					if s_p = '1' then
						if count < 100 then
							count := count + 1;
						elsif count >= 100 then
							cou <= cou + 1;
							count := 0;
							if cou > 999 then
								cou <= 0;
							end if;
						end if;
					else
						count := 0;
						cou <= cou;
					end if;

					seg_data <= "00000" & to_string(cou, 999, 10, 3);

					if k_flag = '1' and key_data = 13 and sw = "00" then
						count := 0;
						mode_t <= m0;
					elsif k_flag = '1' and key_data = 13 and sw = "01" then
						s_p := '0';
						cou <= 0;
						count := 0;
						mode_t <= m1;
					elsif k_flag = '1' and key_data = 13 and sw = "10" then
						count := 0;
						speed_con := 2;
						mode_t <= m2;
					elsif k_flag = '1' and key_data = 15 then
						s_p := not s_p;
					elsif k_flag = '1' and key_data = 13 and sw = "11" then
						count := 0;
						seg_data <= SOH & "       ";
						mode_t <= m3;
					end if;

				when m2 =>
					if count >= 9800 / speed_con then
						count := 0;
					else
						count := count + 1;
					end if;

					if count <= 100 * 2 / speed_con then
						seg_data <= SOH & "       ";
					elsif count <= 200 * 2 / speed_con then
						seg_data <= STX & "       ";
					elsif count <= 300 * 2 / speed_con then
						seg_data <= ETX & "       ";
					elsif count <= 400 * 2 / speed_con then
						seg_data <= ' ' & EOT & "      ";
					elsif count <= 600 * 2 / speed_con then
						seg_data <= ' ' & ETX & "      ";
					elsif count <= 700 * 2 / speed_con then
						seg_data <= ' ' & STX & "      ";
					elsif count <= 800 * 2 / speed_con then
						seg_data <= "  " & SOH & "     ";
					elsif count <= 900 * 2 / speed_con then
						seg_data <= "  " & STX & "     ";
					elsif count <= 1000 * 2 / speed_con then
						seg_data <= "  " & ETX & "     ";
					elsif count <= 1100 * 2 / speed_con then
						seg_data <= "   " & EOT & "    ";
					elsif count <= 1200 * 2 / speed_con then
						seg_data <= "   " & ETX & "    ";
					elsif count <= 1300 * 2 / speed_con then
						seg_data <= "   " & STX & "    ";
					elsif count <= 1400 * 2 / speed_con then
						seg_data <= "    " & SOH & "   ";
					elsif count <= 1500 * 2 / speed_con then
						seg_data <= "    " & STX & "   ";
					elsif count <= 1600 * 2 / speed_con then
						seg_data <= "    " & ETX & "   ";
					elsif count <= 1700 * 2 / speed_con then
						seg_data <= "     " & EOT & "  ";
					elsif count <= 1800 * 2 / speed_con then
						seg_data <= "     " & ETX & "  ";
					elsif count <= 1900 * 2 / speed_con then
						seg_data <= "     " & STX & "  ";
					elsif count <= 2000 * 2 / speed_con then
						seg_data <= "      " & SOH & ' ';
					elsif count <= 2100 * 2 / speed_con then
						seg_data <= "      " & STX & ' ';
					elsif count <= 2200 * 2 / speed_con then
						seg_data <= "      " & ETX & ' ';
					elsif count <= 2300 * 2 / speed_con then
						seg_data <= "       " & EOT;
					elsif count <= 2400 * 2 / speed_con then
						seg_data <= "       " & ETX;
					elsif count <= 2500 * 2 / speed_con then
						seg_data <= "       " & STX;
					elsif count <= 2600 * 2 / speed_con then
						seg_data <= "       " & SOH;
					elsif count <= 2700 * 2 / speed_con then
						seg_data <= "       " & ACK;
					elsif count <= 2800 * 2 / speed_con then
						seg_data <= "       " & ENQ;
					elsif count <= 2900 * 2 / speed_con then
						seg_data <= "      " & EOT & ' ';
					elsif count <= 3000 * 2 / speed_con then
						seg_data <= "      " & ENQ & ' ';
					elsif count <= 3100 * 2 / speed_con then
						seg_data <= "      " & ACK & ' ';
					elsif count <= 3200 * 2 / speed_con then
						seg_data <= "     " & SOH & "  ";
					elsif count <= 3300 * 2 / speed_con then
						seg_data <= "     " & ACK & "  ";
					elsif count <= 3400 * 2 / speed_con then
						seg_data <= "     " & ENQ & "  ";
					elsif count <= 3500 * 2 / speed_con then
						seg_data <= "    " & EOT & "   ";
					elsif count <= 3600 * 2 / speed_con then
						seg_data <= "    " & ENQ & "   ";
					elsif count <= 3700 * 2 / speed_con then
						seg_data <= "    " & ACK & "   ";
					elsif count <= 3800 * 2 / speed_con then
						seg_data <= "   " & SOH & "    ";
					elsif count <= 3900 * 2 / speed_con then
						seg_data <= "   " & ACK & "    ";
					elsif count <= 4000 * 2 / speed_con then
						seg_data <= "   " & ENQ & "    ";
					elsif count <= 4100 * 2 / speed_con then
						seg_data <= "  " & EOT & "     ";
					elsif count <= 4200 * 2 / speed_con then
						seg_data <= "  " & ENQ & "     ";
					elsif count <= 4300 * 2 / speed_con then
						seg_data <= "  " & ACK & "     ";
					elsif count <= 4400 * 2 / speed_con then
						seg_data <= " " & SOH & "      ";
					elsif count <= 4500 * 2 / speed_con then
						seg_data <= " " & ACK & "      ";
					elsif count <= 4600 * 2 / speed_con then
						seg_data <= " " & ENQ & "      ";
					elsif count <= 4700 * 2 / speed_con then
						seg_data <= EOT & "       ";
					elsif count <= 4800 * 2 / speed_con then
						seg_data <= ENQ & "       ";
					elsif count <= 4900 * 2 / speed_con then
						seg_data <= ACK & "       ";
					end if;

					if k_flag = '1' and key_data = 13 and sw = "00" then
						count := 0;
						mode_t <= m0;
					elsif k_flag = '1' and key_data = 13 and sw = "01" then
						s_p := '0';
						cou <= 0;
						count := 0;
						mode_t <= m1;
					elsif k_flag = '1' and key_data = 13 and sw = "10" then
						count := 0;
						speed_con := 2;
						mode_t <= m2;
					elsif k_flag = '1' and key_data = 15 then
						if speed_con = 1 then
							speed_con := 2;
							count := count / 2;
						else
							speed_con := 1;
							count := count * 2;
						end if;
					elsif k_flag = '1' and key_data = 13 and sw = "11" then
						count := 0;
						seg_data <= SOH & "       ";
						mode_t <= m3;
					end if;
				when m3 =>
					case seg_m is
						when la =>
							if count > 1000 then
								count := 0;
							else
								count := count + 1;
							end if;
							if seg_data = SOH & "       " and count = 1000 then
								seg_data <= ' ' & SOH & "      ";
							elsif seg_data = ' ' & SOH & "      " and count = 1000 then
								seg_data <= "  " & SOH & "     ";
							elsif seg_data = "  " & SOH & "     " and count = 1000 then
								seg_data <= "   " & SOH & "    ";
							elsif seg_data = "   " & SOH & "    " and count = 1000 then
								seg_data <= "    " & SOH & "   ";
							elsif seg_data = "    " & SOH & "   " and count = 1000 then
								seg_data <= "     " & SOH & "  ";
							elsif seg_data = "     " & SOH & "  " and count = 1000 then
								seg_data <= "      " & SOH & ' ';
							elsif seg_data = "      " & SOH & ' ' and count = 1000 then
								seg_data <= "       " & SOH;
							elsif seg_data = "       " & SOH and count = 1000 then
								seg_data <= SOH & "       ";
							end if;

							if k_flag = '1' and key_data = 15 then
								count := 0;
								seg_m <= lb;
							end if;
						when lb =>
							if count > 1000 then
								count := 0;
							else
								count := count + 1;
							end if;
							if seg_data = SOH & "       " and count = 1000 then
								seg_data <= STX & "       ";
							elsif seg_data = STX & "       " and count = 1000 then
								seg_data <= ETX & "       ";
							end if;

							if seg_data = ' ' & SOH & "      " and count = 1000 then
								seg_data <= ' ' & STX & "      ";
							elsif seg_data = ' ' & STX & "      " and count = 1000 then
								seg_data <= ' ' & ETX & "      ";
							end if;

							if seg_data = "  " & SOH & "     " and count = 1000 then
								seg_data <= "  " & STX & "     ";
							elsif seg_data = "  " & STX & "     " and count = 1000 then
								seg_data <= "  " & ETX & "     ";
							end if;

							if seg_data = "   " & SOH & "    " and count = 1000 then
								seg_data <= "   " & STX & "    ";
							elsif seg_data = "   " & STX & "    " and count = 1000 then
								seg_data <= "   " & ETX & "    ";
							end if;

							if seg_data = "    " & SOH & "   " and count = 1000 then
								seg_data <= "    " & STX & "   ";
							elsif seg_data = "    " & STX & "   " and count = 1000 then
								seg_data <= "    " & ETX & "   ";
							end if;

							if seg_data = "     " & SOH & "   "and count = 1000 then
								seg_data <= "     " & STX & "  ";
							elsif seg_data = "     " & STX & "  " and count = 1000 then
								seg_data <= "     " & ETX & "  ";
							end if;

							if seg_data = "      " & SOH & ' ' and count = 1000 then
								seg_data <= "      " & STX & ' ';
							elsif seg_data = "      " & STX & ' ' and count = 1000 then
								seg_data <= "      " & ETX & ' ';
							end if;

							if seg_data = "       " & SOH and count = 1000 then
								seg_data <= "       " & STX;
							elsif seg_data = "       " & STX and count = 1000 then
								seg_data <= "       " & ETX;
							end if;

							if k_flag = '1' and key_data = 15 then
								if seg_data = ETX & "       " or seg_data = STX & "       " then
									seg_data <= EOT & "       ";
								elsif seg_data = ' ' & ETX & "      " or seg_data = ' ' & STX & "      " then
									seg_data <= ' ' & EOT & "      ";
								elsif seg_data = "  " & ETX & "     " or seg_data = "  " & STX & "     " then
									seg_data <= "  " & EOT & "     ";
								elsif seg_data = "   " & ETX & "    " or seg_data = "   " & STX & "    " then
									seg_data <= "   " & EOT & "    ";
								elsif seg_data = "    " & ETX & "   " or seg_data = "    " & STX & "   " then
									seg_data <= "    " & EOT & "   ";
								elsif seg_data = "     " & ETX & "  " or seg_data = "     " & STX & "  " then
									seg_data <= "     " & EOT & "  ";
								elsif seg_data = "      " & ETX & ' ' or seg_data = "      " & STX & ' ' then
									seg_data <= "      " & EOT & ' ';
								elsif seg_data = "       " & ETX or seg_data = "       " & STX then
									seg_data <= "       " & EOT;
								end if;
								count := 0;
								seg_m <= ld;
							end if;
						when ld =>
							if count > 1000 then
								count := 0;
							else
								count := count + 1;
							end if;
							if seg_data = EOT & "       " and count = 1000 then
								seg_data <= ' ' & EOT & "      ";
							elsif seg_data = ' ' & EOT & "      " and count = 1000 then
								seg_data <= "  " & EOT & "     ";
							elsif seg_data = "  " & EOT & "     " and count = 1000 then
								seg_data <= "   " & EOT & "    ";
							elsif seg_data = "   " & EOT & "    " and count = 1000 then
								seg_data <= "    " & EOT & "   ";
							elsif seg_data = "    " & EOT & "   " and count = 1000 then
								seg_data <= "     " & EOT & "  ";
							elsif seg_data = "     " & EOT & "  " and count = 1000 then
								seg_data <= "      " & EOT & ' ';
							elsif seg_data = "      " & EOT & ' ' and count = 1000 then
								seg_data <= "       " & EOT;
							elsif seg_data = "       " & EOT and count = 1000 then
								seg_data <= EOT & "       ";
							end if;

							if k_flag = '1' and key_data = 15 then
								count := 0;
								seg_m <= le;
							end if;
						when le =>
							if count > 1000 then
								count := 0;
							else
								count := count + 1;
							end if;
							if seg_data = EOT & "       " and count = 1000 then
								seg_data <= ENQ & "       ";
							elsif seg_data = ENQ & "       " and count = 1000 then
								seg_data <= ACK & "       ";
							end if;

							if seg_data = ' ' & EOT & "      " and count = 1000 then
								seg_data <= ' ' & ENQ & "      ";
							elsif seg_data = ' ' & ENQ & "      " and count = 1000 then
								seg_data <= ' ' & ACK & "      ";
							end if;

							if seg_data = "  " & EOT & "     " and count = 1000 then
								seg_data <= "  " & ENQ & "     ";
							elsif seg_data = "  " & ENQ & "     " and count = 1000 then
								seg_data <= "  " & ACK & "     ";
							end if;

							if seg_data = "   " & EOT & "    " and count = 1000 then
								seg_data <= "   " & ENQ & "    ";
							elsif seg_data = "   " & ENQ & "    " and count = 1000 then
								seg_data <= "   " & ACK & "    ";
							end if;

							if seg_data = "    " & EOT & "   " and count = 1000 then
								seg_data <= "    " & ENQ & "   ";
							elsif seg_data = "    " & ENQ & "   " and count = 1000 then
								seg_data <= "    " & ACK & "   ";
							end if;

							if seg_data = "     " & EOT & "   "and count = 1000 then
								seg_data <= "     " & ENQ & "  ";
							elsif seg_data = "     " & ENQ & "  " and count = 1000 then
								seg_data <= "     " & ACK & "  ";
							end if;

							if seg_data = "      " & EOT & ' ' and count = 1000 then
								seg_data <= "      " & ENQ & ' ';
							elsif seg_data = "      " & ENQ & ' ' and count = 1000 then
								seg_data <= "      " & ACK & ' ';
							end if;

							if seg_data = "       " & EOT and count = 1000 then
								seg_data <= "       " & ENQ;
							elsif seg_data = "       " & ENQ and count = 1000 then
								seg_data <= "       " & ACK;
							end if;

							if k_flag = '1' and key_data = 15 then
								if seg_data = ACK & "       " or seg_data = ENQ & "       " then
									seg_data <= SOH & "       ";
								elsif seg_data = ' ' & ACK & "      " or seg_data = ' ' & ENQ & "      " then
									seg_data <= ' ' & SOH & "      ";
								elsif seg_data = "  " & ACK & "     " or seg_data = "  " & ENQ & "     " then
									seg_data <= "  " & SOH & "     ";
								elsif seg_data = "   " & ACK & "    " or seg_data = "   " & ENQ & "    " then
									seg_data <= "   " & SOH & "    ";
								elsif seg_data = "    " & ACK & "   " or seg_data = "    " & ENQ & "   " then
									seg_data <= "    " & SOH & "   ";
								elsif seg_data = "     " & ACK & "  " or seg_data = "     " & ENQ & "  " then
									seg_data <= "     " & SOH & "  ";
								elsif seg_data = "      " & ACK & ' ' or seg_data = "      " & ENQ & ' ' then
									seg_data <= "      " & SOH & ' ';
								elsif seg_data = "       " & ACK or seg_data = "      " & ENQ then
									seg_data <= "       " & SOH;
								end if;
								count := 0;
								seg_m <= la;
							end if;
					end case;
					if k_flag = '1' and key_data = 13 and sw = "00" then
						count := 0;
						mode_t <= m0;
					elsif k_flag = '1' and key_data = 13 and sw = "01" then
						s_p := '0';
						cou <= 0;
						count := 0;
						mode_t <= m1;
					elsif k_flag = '1' and key_data = 13 and sw = "10" then
						count := 0;
						speed_con := 2;
						mode_t <= m2;
					elsif k_flag = '1' and key_data = 13 and sw = "11" then
						count := 0;
						seg_data <= SOH & "       ";
						mode_t <= m3;
					end if;
				when m4 =>
					seg_data <= "        ";

					if k_flag = '1' and key_data = 13 and sw = "00" then
						count := 0;
						mode_t <= m0;
					elsif k_flag = '1' and key_data = 13 and sw = "01" then
						s_p := '0';
						cou <= 0;
						count := 0;
						mode_t <= m1;
					elsif k_flag = '1' and key_data = 13 and sw = "10" then
						count := 0;
						speed_con := 2;
						mode_t <= m2;
					elsif k_flag = '1' and key_data = 13 and sw = "11" then
						count := 0;
						seg_data <= SOH & "       ";
						mode_t <= m3;
					end if;

			end case;
		end if;
	end process;
end architecture;

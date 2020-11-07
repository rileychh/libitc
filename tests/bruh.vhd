library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.bruh_data_all;

entity bruh is
	port (
		-- sys
		clk, rst_n : in std_logic; -- rising edge clock, low reset
		-- sw
		sw : in byte_t;
		-- seg
		seg_1, seg_2, seg_s : out byte_be_t; -- abcdefgp * 2, seg2_s1 ~ seg1_s4
		-- key
		key_row : in nibble_be_t;
		key_col : out nibble_be_t;
		-- dht
		dht_data : inout std_logic;
		-- tsl
		tsl_scl, tsl_sda : inout std_logic;
		-- tts
		tts_scl, tts_sda : inout std_logic
	);
end bruh;

architecture arch of bruh is

	signal sw_i : byte_t;
	signal seg : string(1 to 8);
	signal seg_dot : byte_t;
	signal pressed : std_logic;
	signal key : integer range 0 to 15;
	signal temp, hum : integer range 0 to 99;
	signal lux : integer range 0 to 40000;
	signal tts_ena, tts_busy : std_logic;
	signal txt : bytes_t(0 to txt_len_max - 1);
	signal txt_len : integer range 0 to txt_len;

	signal mode : integer range 0 to 3;
	constant key_start_stop : integer := 0;
	constant key_rst : integer := 1;
	constant key_func : integer := 2;
	constant key_up : integer := 6;
	constant key_down : integer := 7;
	constant key_ok : integer := 8;

	type state_t is (idle, lcd_test, tts_test, sensors_test, combined_test);

begin

	sw_inst : entity work.sw(arch)
		port map(
			clk    => clk,
			rst_n  => rst_n,
			sw     => sw,
			sw_out => sw_i
		);

	seg_inst : entity work.seg(arch)
		port map(
			clk   => clk,
			rst_n => rst_n,
			seg_1 => seg_1,
			seg_2 => seg_2,
			seg_s => seg_s,
			data  => seg,
			dot   => seg_dot
		);

	key_inst : entity work.key(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			key_row => key_row,
			key_col => key_col,
			pressed => pressed,
			key     => key
		);

	dht_inst : entity work.dht(arch)
		port map(
			clk      => clk,
			rst_n    => rst_n,
			dht_data => dht_data,
			temp_int => temp,
			temp_dec => open,
			hum_int  => hum,
			hum_dec  => open
		);

	tsl_inst : entity work.tsl(arch)
		port map(
			tsl_scl => tsl_scl,
			tsl_sda => tsl_sda,
			clk     => clk,
			rst_n   => rst_n,
			lux     => lux
		);

	tts_inst : entity work.tts(arch)
		generic map(
			txt_len_max => txt_len_max
		)
		port map(
			tts_scl => tts_scl,
			tts_sda => tts_sda,
			clk     => clk,
			rst_n   => rst_n,
			ena     => tts_ena,
			busy    => tts_busy,
			txt     => txt,
			txt_len => txt_len
		);

	process (clk, rst_n)
		-- tts_test vars	
		variable func : integer range 0 to 3;
		variable param : string(1 to 5); -- parameter of function displayed on seg
		variable vol : integer range 0 to 9; -- func 1 param: volume
		variable output_content : std_logic; -- func 2 param: text (low) or music (high)
	begin
		if rst_n = '0' then
			state <= idle;
			elsif rising_edge(clk) then
			case state is
				when idle =>
					if pressed = '1' and key = key_start_stop then
						mode <= to_integer(sw(7 downto 6));
					end if;

				when run =>
					if pressed = '1' and key = key_start_stop then
						state <= pause;
					end if;

					case mode is
						when 0 => -- lcd_test
						when 1 => -- tts_test
							tts_ena <= '0';

							if pressed = '1' then
								case key is
									when key_rst =>
										func := 1;
										vol := 5;
									when key_func =>
										if func = 3 then -- loop between functions
											func <= 1;
										else
											func <= func + 1;
										end if;
									when others => null;
								end case;
							end if;

							case func is
								when 1 => -- vol
									if pressed = '1' then
										case key is
											when key_up =>
												vol := vol + 1;
											when key_down =>
												vol := vol - 1;
											when key_ok =>
												txt(0 to 1) <= tts_set_vol & (2 ** 8 / 10) * vol; -- map 256 volume steps to 10 volume steps
												txt_len <= 2;
												tts_ena <= '1';
											when others => null;
										end case;
									end if;
									seg <= "F1 VOL" & to_string(vol, vol'high, 10, 2);
									seg_dot <= "00100000";

								when 2 => -- speak & music
									if pressed = '1' then
										case key is
											when key_down =>
												output_content := not output_content;
											when key_ok =>
												if output_content = '0' then -- text
													tts_txt(0 to 45) <= txt_sensor_init;
													tts_txt_len <= 46;
												else -- music
													tts_txt(0 to 4) <= tts_play_file & x"0001" & x"0001"; -- play 0001.wav 1 time
													tts_txt_len <= 5;
												end if;
												tts_ena <= '1';
											when others => null;
										end case;
									end if;

									seg(1 to 3) <= "F2 ";
									if output_content = '0' then -- text
										seg(4 to 8) <= "SPEAt";
									else -- music
										seg(4 to 8) <= "3US1C";
									end if;
									seg_dot <= "00100001";

								when 3 => -- output channel
									if pressed = '1' then
										case key is
											when key_down =>

										end case;
									end if;

							end case;

						when 2 => -- sensors_test
						when 3 => -- combined_test
					end case;

				when pause =>
					if pressed = '1' and key = key_start_stop then
						state <= run;
					end if;

			end case;
		end if;
	end process;

end arch;

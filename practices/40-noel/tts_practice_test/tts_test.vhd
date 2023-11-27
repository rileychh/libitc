--play 3 times before go to blank file

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;

entity tts_test is
	port (
		clk              : in std_logic;
		rst_n            : in std_logic;
		tts_scl, tts_sda : inout std_logic;
		tts_mo           : in unsigned(2 downto 0);
		tts_rst_n        : out std_logic;
		key_row          : in u4r_t;
		key_col          : out u4r_t;
		sw               : in u8r_t;
		seg_led, seg_com : out u8r_t
	);
end tts_test;

architecture arch of tts_test is
-- "一二三四五六七", 14
-- tts_data(0 to 13) <= one_to_seven;
-- tts_len <= 14;
constant one_to_seven : u8_arr_t(0 to 13) := (
        x"a4", x"40", x"a4", x"47", x"a4", x"54", x"a5", x"7c", x"a4", x"ad", x"a4", x"bb", x"a4", x"43"
);
constant music : u8_arr_t(0 to 4) := (tts_play_file, x"00", x"01", x"00", x"01");
constant vol : u8_arr_t(0 to 1) := (tts_set_vol, x"ff");
constant speed : u8_arr_t(0 to 1) := (tts_set_speed, x"28");
-- "   ", 3
-- tts_data(0 to 2) <= space;
-- tts_len <= 3;
constant space : u8_arr_t(0 to 1) := (
        x"20", x"20"
);
-- "測試開始", 8
-- tts_data(0 to 7) <= start;
-- tts_len <= 8;
constant start : u8_arr_t(0 to 7) := (
        x"b4", x"fa", x"b8", x"d5", x"b6", x"7d", x"a9", x"6c"
);
-- "測試結束", 8
-- tts_data(0 to 7) <= test_end;
-- tts_len <= 8;
constant test_end : u8_arr_t(0 to 7) := (
        x"b4", x"fa", x"b8", x"d5", x"b5", x"b2", x"a7", x"f4"
);

	type tts_mod_t is (idle, send, stop);
	signal tts_mod : tts_mod_t;

	constant txt_len_max : integer := 100;
	signal ena : std_logic;
	signal busy : std_logic;
	signal txt : u8_arr_t(0 to txt_len_max - 1);
	signal txt_len : integer range 0 to txt_len_max;
	signal count : integer range 0 to 6;

	signal data : string(1 to 8);
	signal dot : u8r_t;

	signal pressed, key_pressed : std_logic;
	signal key_data : i4_t;

	signal stop_flag, reset_flag, change_flag : std_logic;
	signal mod0, mod1 : std_logic;
	signal count_time : integer range 0 to 2; 

begin
	edge_sw_inst: entity work.edge(arch)
	port map (
		clk     => clk,
		rst_n   => rst_n,
		sig_in  => sw(0),
		rising  => mod1,
		falling => mod0 
	);
	key_inst: entity work.key(arch)
	port map (
		clk     => clk,
		rst_n   => rst_n,
		key_row => key_row,
		key_col => key_col,
		pressed => pressed,
		key     => key_data 
	);
	edge_inst: entity work.edge(arch)
	port map (
		clk     => clk,
		rst_n   => rst_n,
		sig_in  => pressed,
		rising  => key_pressed,
		falling => open 
	);
	seg_inst: entity work.seg(arch)
	generic map (
		common_anode => '1'
	)
	port map (
		clk     => clk,
		rst_n   => rst_n,
		seg_led => seg_led,
		seg_com => seg_com,
		data    => data,
		dot     => dot 
	);
	tts_stop_inst : entity work.tts_stop(arch)
		generic map(
			txt_len_max => txt_len_max
		)
		port map(
			clk        => clk,
			rst_n      => rst_n,
			tts_scl    => tts_scl,
			tts_sda    => tts_sda,
			tts_mo     => tts_mo,
			tts_rst_n  => tts_rst_n,
			ena        => ena,
			busy       => busy,
			stop_speak => open,
			txt        => txt,
			txt_len    => txt_len
		);
	process (clk, rst_n)
	begin
		if rst_n = '0' then
			ena <= '0';
			tts_mod <= idle;
			stop_flag <= '0';
			data <= "        ";
			count <= 0;
			txt(0 to 1) <= space;
			txt_len <= 2;
			reset_flag <= '0';
			count_time <= 0;
		elsif rising_edge(clk) then
			if mod1 = '1' then
				change_flag <= '1';
			elsif mod0 = '1' then
				change_flag <= '0';
			end if;
			case tts_mod is
				when idle =>
					ena <= '0';
					if busy = '0' then
						tts_mod <= send;
					end if;
				when send =>
					ena <= '1';
					if count = 0 then
						txt(0 to 13) <= one_to_seven;
						txt_len <= 14;
						reset_flag <= '0';
						data <= "0       ";
						count_time <= count_time + 1;
					elsif count = 1 then
						txt(0 to 13) <= one_to_seven;
						txt_len <= 14;
						reset_flag <= '0';
						data <= "1       ";
						count_time <= count_time + 1;						
					elsif count = 2 then
						txt(0 to 13) <= one_to_seven;
						txt_len <= 14;
						reset_flag <= '0';
						data <= "2       ";
						count_time <= count_time + 1;
					elsif count = 3 then
						txt(0 to 1) <= tts_instant_soft_reset;
						txt_len <= 2;
						reset_flag <= '1';
						data <= "3       ";
					elsif count = 4 then
						txt(0 to 1) <= tts_instant_soft_reset;
						txt_len <= 2;
						data <= "4       ";						
					elsif count = 5 then
						txt(0 to 1) <= space;
						txt_len <= 2;
						data <= "5       ";
					elsif count = 6 then
						txt(0 to 4) <= music;
						txt_len <= 5;
						reset_flag <= '0';
						data <= "6       ";
					end if;
					if busy = '1' then
						tts_mod <= stop;
					end if;
				when stop =>
					if count = 0 and reset_flag = '0' and stop_flag = '0' then
						count <= 1;
					elsif count = 1 and reset_flag = '0' and stop_flag = '0' then
						count <= 2;
					elsif count = 2 and reset_flag = '0' and stop_flag = '0' then
						count <= 5;
					end if;
					ena <= '0';
					tts_mod <= idle;
			end case;
		end if;
	end process;
end arch;

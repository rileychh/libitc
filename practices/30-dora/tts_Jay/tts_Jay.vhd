Library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;
entity tts_jay is
	port
	(
		clk, rst_n : in std_logic;
		-- key
		key_row : in u4r_t;
		key_col : out u4r_t;

		--seg
		seg_led, seg_com : out u8r_t;

		-- tts
		tts_scl, tts_sda : inout std_logic;
		tts_mo           : in unsigned(2 downto 0);
		tts_rst_n        : out std_logic
	);
end tts_jay;

architecture rtl of tts_jay is
------------------------------------------------------------------signal
--seg
signal seg_data:string(1 to 8):=(others=>' ');
signal dot:u8r_t:=(others=>'0');
--key
signal pressed, pressed_i : std_logic;
signal key : i4_t;
--tts
signal abc : unsigned(2 downto 0);
signal tts_ena : std_logic;
signal tts_busy : std_logic;
signal tts_stop_flag,tts_continue_flag: std_logic;
signal tts_done : std_logic;
type tts_mode_t is (idle,send,stop);
signal tts_mode : tts_mode_t;
type tts_pause_t is (idle,send,stop);
signal tts_pause : tts_pause_t;
constant max_len : integer := 100;
signal txt : u8_arr_t(0 to max_len - 1);
signal len : integer range 0 to max_len;
signal play_count : integer range 0 to 3 ;
signal count : integer range 0 to 50;
-- constant star : u8_arr_t(0 to 29) :=(
--         x"a4", x"40", x"b0", x"7b", x"a4", x"40", x"b0", x"7b", x"ab", x"47", x"b4", x"b9", x"b4", x"b9", x"a1", x"40",
--         x"ba", x"a1", x"a4", x"d1", x"b3", x"a3", x"ac", x"4f", x"a4", x"70", x"ac", x"50", x"ac", x"50"
-- );
-- constant bee : u8_arr_t(0 to 51) := (
--         x"b6", x"e4", x"b6", x"e4", x"b6", x"e4", x"a1", x"41", x"b6", x"e4", x"b6", x"e4", x"b6", x"e4", x"a4", x"6a",
--         x"ae", x"61", x"a4", x"40", x"b0", x"5f", x"b6", x"d4", x"b0", x"b5", x"a4", x"75", x"a8", x"d3", x"a5", x"5e",
--         x"a5", x"5e", x"a1", x"41", x"a5", x"68", x"a5", x"5e", x"a5", x"5e", x"b0", x"b5", x"a4", x"75", x"bf", x"b3",
--         x"a8", x"fd", x"bf", x"40"
-- );
-- constant tiger : u8_arr_t(0 to 27) := (
--         x"a8", x"e2", x"b0", x"a6", x"a6", x"d1", x"aa", x"ea", x"a8", x"e2", x"b0", x"a6", x"a6", x"d1", x"aa", x"ea",
--         x"b6", x"5d", x"b1", x"6f", x"a7", x"d6", x"b6", x"5d", x"b1", x"6f", x"a7", x"d6"
-- );
-- constant fuck : u8_arr_t(0 to 5) := (
--         x"b7", x"46", x"a7", x"41", x"ae", x"51"
-- );
constant star  : u8_arr_t(0 to 3) := ( x"03",x"e9",x"00",x"01");--1001.wav
constant tiger : u8_arr_t(0 to 3) := ( x"03",x"ea",x"00",x"02");--1002.wav
constant bee   : u8_arr_t(0 to 3) := ( x"03",x"eb",x"00",x"02");--1003.wav
------------------------------------------------------------------end signal
begin
----------------------------------------begin packages
	------------------------------edge
	edge_inst : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => pressed_i,	--頛詨閮(虜典 4*4 keypad
			rising  => pressed,		--甇楠 '1'閫貊
			falling => open			--鞎楠 open=楝
		);
	key_inst : entity work.key(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			key_row => key_row,		--喃
			key_col => key_col,		--喃
			pressed => pressed_i,	--pressed='1' 隞”
			key     => key			--key=0 隞” key 1	key=1 隞” key 2...........
		);
	edge_inst3 : entity work.edge(arch)
		port map
		(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => tts_busy,
			rising  => open,		
			falling => tts_done			
		);	
	--
		-- tts_inst: entity work.tts_stop(arch)
		-- 	generic map (
		-- 			txt_len_max => max_len
		-- 		)
		-- 	port map (
		-- 		clk => clk,
		-- 		rst_n => rst_n,
		-- 		tts_scl => tts_scl,			
		-- 		tts_sda => tts_sda,			
		-- 		tts_mo => tts_mo,			
		-- 		tts_rst_n => tts_rst_n,
		-- 		abc=>abc,
		-- 		stop_flag=>tts_stop_flag,
		-- 		ena => tts_ena,				
		-- 		busy => tts_busy,				
		-- 		txt => txt,
		-- 		txt_len => len				
		-- 	);
	tts_inst: entity work.tts_stop(arch)
		generic map (
				txt_len_max => max_len
			)
		port map (
			clk => clk,
			rst_n => rst_n,
			tts_scl => tts_scl,
			tts_sda => tts_sda,
			tts_mo => tts_mo,
			tts_rst_n => tts_rst_n,
			ena => tts_ena,
			busy => tts_busy,
			txt => txt,
			txt_len => len
		);
	seg_inst : entity work.seg(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			seg_led => seg_led,		--喃 a~g
			seg_com => seg_com,		--勗喃
			data    => seg_data,	--銝挾鞈 頛詨閬＊蝷箏格撓亦征
			dot     => dot			--撠暺1 鈭
									--頛詨鞈ex: b"01000000" = x"70"  
									--seg_deg 摨列
		);
	process(clk,rst_n)
	begin
		if rst_n='0' then
			tts_ena<='0';
			tts_mode<=idle;
			play_count<=1;
			seg_data<="        ";
			tts_stop_flag<='0';
			tts_continue_flag<='1';
		elsif rising_edge(clk) then
			seg_data<=to_string(to_integer(abc),9,10,1)&"       ";
			if pressed='1' and key=15 then
				tts_stop_flag<= not tts_stop_flag;
			end if;
			case tts_mode is
				when idle=>
					if pressed='1' and (key=0 or key=15)  then--and tts_stop_flag='0'
						tts_mode<=send;
						tts_ena<='1';
					end if;
				when send=>
					if key=0 then
						len<=5;
						txt(0 to 4)<=tts_play_file & star;
					else
						if tts_stop_flag='1' then
							len<=2;
							txt(0 to 1)<=tts_instant_pause;
						else
							len<=2;
							txt(0 to 1)<=tts_instant_resume;
						end if;
					end if;
					tts_ena <= '0';
					if tts_done='1' then
						tts_mode<= stop;
					end if;
				when stop=>
					if tts_busy = '0' then
						tts_mode<= idle;
					end if;
				when others=>null;
			end case;
		end if;
	end process;
end architecture;
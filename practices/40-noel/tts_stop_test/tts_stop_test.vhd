library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;

entity tts_stop_test is
	port (
		clk              : in std_logic;
		rst_n            : in std_logic;
		tts_scl, tts_sda : inout std_logic;
		tts_mo           : in unsigned(2 downto 0);
		tts_rst_n        : out std_logic;

		key_row : in u4r_t;
		key_col : out u4r_t;

		seg_led, seg_com : out u8r_t
	);
end tts_stop_test;

architecture arch of tts_stop_test is
	type tts_mode_t is (idle, send, stop);
	signal tts_mode : tts_mode_t;
	signal tts_count : integer range 0 to 3;
	signal stop_flag : std_logic;
	signal reset_flag : std_logic;

	signal pressed, key_pressed : std_logic;
	signal key_data : i4_t;

	signal seg_data : string(1 to 8);
	signal seg_dot : u8r_t;

	constant max_len : integer := 100;
	signal ena : std_logic;
	signal busy, done : std_logic;
	signal txt : u8_arr_t(0 to max_len - 1);
	signal txt_len : integer range 0 to max_len;

-- "測試開始", 8
-- tts_data(0 to 7) <= start;
-- tts_len <= 8;
constant start : u8_arr_t(0 to 7) := (
        x"b4", x"fa", x"b8", x"d5", x"b6", x"7d", x"a9", x"6c"
);

-- "正在測試中", 10
-- tts_data(0 to 9) <= testing;
-- tts_len <= 10;
	constant testing : u8_arr_t(0 to 9) := (
        x"a5", x"bf", x"a6", x"62", x"b4", x"fa", x"b8", x"d5", x"a4", x"a4"
	);

-- "測試結束", 8
-- tts_data(0 to 7) <= end;
-- tts_len <= 8;
	constant test_end : u8_arr_t(0 to 9) := (
        x"b4", x"fa", x"b8", x"d5", x"b5", x"b2", x"a7", x"f4", x"00", x"00"
	);
-- "一二三是五六七八九十", 20
-- tts_data(0 to 19) <= tt;
-- tts_len <= 20;
constant tt : u8_arr_t(0 to 19) := (
        x"a4", x"40", x"a4", x"47", x"a4", x"54", x"ac", x"4f", x"a4", x"ad", x"a4", x"bb", x"a4", x"43", x"a4", x"4b",
        x"a4", x"45", x"a4", x"51"
);

begin
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
	tts_stop_inst : entity work.tts_stop(arch)
		generic map(
			txt_len_max => max_len
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
	edge_tts_inst : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => busy,
			rising  => open,
			falling => done
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
		data    => seg_data,
		dot     => seg_dot
	);

	process (clk, rst_n)
	begin
		if rst_n = '0' then
			ena <= '0';
			tts_mode <= idle;
			tts_count <= 0;
			stop_flag <= '0';
			reset_flag <= '0';
		elsif rising_edge(clk) then
			-- if stop_flag = '0' then
			-- 	seg_data <= "11111111";
			-- elsif stop_flag = '1' then
			-- 	seg_data <= "22222222";
			-- elsif stop_flag = '1' and tts_count = 3 then
			-- 	seg_data <= "00000000";
			-- end if;
			if key_pressed = '1' and key_data = 0 then
				stop_flag <= not stop_flag;
			end if;
			case tts_mode is
				when idle =>
				seg_data <= "2       ";
					if busy = '0' then
						tts_mode <= send;
					end if;
				when send =>
					
					case tts_count is
						when 0 =>
							txt(0 to 19) <= tt;
							txt_len <= 20;
							seg_data <= "       1";
							ena <= '1';
						when 1 =>
							txt(0 to 9) <= testing;
							txt_len <= 10;
							seg_data <= "       2";
							ena <= '1';
						when 2 =>
							txt(0 to 1) <= tts_instant_soft_reset;
							txt_len <= 2;
							seg_data <= "       3";
							reset_flag <= '1';
							ena <= '1';
						when 3 =>
							txt(0 to 1) <= tts_instant_soft_reset;
							txt_len <= 2;
							seg_data <= "       4";
							ena <= '1';
						when others =>
					end case;
					if done = '1' then
						if tts_count = 1 and stop_flag = '1' then
							tts_count <= 2;
						elsif tts_count = 1 and reset_flag = '0' then
							tts_count <= 1;
						elsif tts_count < 1 and reset_flag = '0' then
							tts_count <= tts_count + 1;
						elsif tts_count = 2 and stop_flag = '1' then
							tts_count <= 3;
						elsif tts_count = 3 and stop_flag = '1' then
							tts_count <= 0;
						elsif tts_count = 0 and reset_flag = '1' then
							tts_count <= 0;
						end if;
						tts_mode <= stop;
					end if;
				when stop =>
					if busy = '0' then
						seg_data <= "1       ";
						ena <= '0';
						tts_mode <= idle;
					end if;
					
			end case;
			
		end if;
	end process;
end arch;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package tts_p is
	-- input command type
	type txt_t is array(integer range <>) of unsigned(7 downto 0);

	-- command code constants
	-- IEEE Std 1076-2008, ...Aggregates containing a single element association shall always be specified using named association in order to distinguish them from parenthesized expressions
	-- constant tts_instant_clear : txt_t(0 to 0) := (x"80"); -- DO NOT USE, MAY CRASH MODULE
	constant tts_instant_vol_up : txt_t(0 to 0) := (0 => x"81");
	constant tts_instant_vol_down : txt_t(0 to 0) := (0 => x"82");
	constant tts_instant_pause : txt_t(0 to 1) := (x"8f", x"00");
	constant tts_instant_resume : txt_t(0 to 1) := (x"8f", x"01");
	constant tts_instant_skip : txt_t(0 to 1) := (x"8f", x"02"); -- skips delay or music
	constant tts_instant_soft_reset : txt_t(0 to 1) := (x"8f", x"03"); -- TODO what's the use case?

	-- concatenate 1 speed byte after
	-- e.g. 0x83 0x19 means 25% faster 
	-- range 0x00 to 0x28 (40%)
	-- default is 0x00
	constant tts_set_speed : txt_t(0 to 0) := (0 => x"83");

	-- concatenate 1 volume byte after
	-- e.g. 0xff means 0db, 0xfe means -0.5db, 0x01 means -127db, 0x00 means mute
	-- range 0x00 to 0xff
	-- default is 0xd2 (-105db)
	constant tts_set_vol : txt_t(0 to 0) := (0 => x"86");

	-- concatenate 4 time bytes after
	-- e.g. 0x0001d4c0 means delay 120000ms
	-- range 0x00000000 to 0xffffffff
	constant tts_delay : txt_t(0 to 0) := (0 => x"87");

	-- concatenate 2 filename bytes and 2 repeat bytes after
	-- e.g. 0x03fd_0005 means play "1021.wav" 5 times
	-- filename can be 0x0001 to 0x270f (0001 to 9999)
	-- repeat = 0 means do not stop
	constant tts_play_file : txt_t(0 to 0) := (0 => x"88");

	constant tts_sleep : txt_t(0 to 0) := (0 => x"89");

	-- concatenate 1 state byte after, only last 3 bits (2 downto 0) have an effect
	-- e.g. 0x06 means set MO2, MO1, MO0 = 1, 1, 0
	-- range 0x00 to 0x07
	-- default is 0x07
	constant tts_set_mo : txt_t(0 to 0) := (0 => x"8a");

	-- concatenate 1 mode byte after
	-- | mode  | line out | headphone | speaker |
	-- | :---: | :------: | :-------: | :-----: |
	-- | 0x01  |          |           |    L    |
	-- | 0x02  |          |           |    R    |
	-- | 0x03  |          |           |  both   |
	-- | 0x04  |          |   both    |         |
	-- | 0x05  |          |     L     |    L    |
	-- | 0x06  |          |     R     |    R    |
	-- | 0x07  |          |   both    |  both   |
	-- | 0x08  |   both   |           |         |
	-- | 0x09  |    L     |           |    L    |
	-- | 0x0a  |    R     |           |    R    |
	-- | 0x0b  |   both   |           |  both   |
	constant tts_set_channel : txt_t(0 to 0) := (0 => x"8b");

	component tts
		generic (
			txt_len_max : integer := 16 -- maximum length of text
		);
		port (
			-- tts
			tts_scl, tts_sda : inout std_logic;
			-- system
			clk : in std_logic;
			rst : in std_logic;
			-- user logic
			ena     : in std_logic;
			busy    : out std_logic;
			txt     : in txt_t(0 to txt_len_max - 1);
			txt_len : in integer range 0 to txt_len_max;
			-- d
			d_i2c_ena : out std_logic
		);
	end component;
end package;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.tts_p.all;
use work.clk_p.all;
use work.i2c_p.all;

entity tts is
	generic (
		txt_len_max : integer := 16 -- maximum length of text
	);
	port (
		-- tts
		tts_scl, tts_sda : inout std_logic;
		-- system
		clk : in std_logic;
		rst : in std_logic;
		-- user logic
		ena     : in std_logic; -- start on enable rising edge
		busy    : out std_logic;
		txt     : in txt_t(0 to txt_len_max - 1);
		txt_len : in integer range 0 to txt_len_max;
		-- d
		d_tts_info_1 : out unsigned(7 downto 0)
	);
end tts;

architecture arch of tts is

	constant tts_addr : unsigned(6 downto 0) := "0100000";

	type tts_state_t is (idle, send, speak, check);
	signal state : tts_state_t;

	signal start : std_logic; -- enable rising edge

	signal i2c_ena : std_logic;
	signal i2c_busy : std_logic;
	signal i2c_rw : std_logic;
	signal i2c_in : unsigned(7 downto 0);
	signal i2c_out : unsigned(7 downto 0);
	signal i2c_accepted : std_logic;
	signal i2c_done : std_logic;

	signal txt_cnt : integer range 0 to txt_len_max;

	-- information read from tts
	-- 0, 1: number of unprocessed bytes in buffer (high byte, low byte)
	-- 2, 3: number of available space in buffer (high byte, low byte)
	-- 4: (MO2, MO1, MO0, delaying, playing, speaking, can't find firmware, can't open file), high active
	-- 5: (X, X, X, X, waiting for delay parameter, pausing, waiting for instant command parameter, waiting for normal command parameter), high active
	-- 6, 7: board version (e.g. 0x02 0x02 == v2.2)
	type tts_info_t is array(0 to 7) of unsigned(7 downto 0);
	signal tts_info : tts_info_t;
	signal info_cnt : integer range 0 to 8;

begin
	-- debug
	d_tts_info_1 <= to_unsigned(info_cnt, 8);

	i2c_inst : entity work.i2c(arch)
		generic map(
			bus_freq => 100_000
		)
		port map(
			scl      => tts_scl,
			sda      => tts_sda,
			clk      => clk,
			rst      => rst,
			ena      => i2c_ena,
			busy     => i2c_busy,
			addr     => tts_addr,
			rw       => i2c_rw,
			data_in  => i2c_in,
			data_out => i2c_out
		);

	edge_inst_i2c : entity work.edge(arch)
		port map(
			clk       => clk,
			rst       => rst,
			signal_in => i2c_busy,
			rising    => i2c_accepted,
			falling   => i2c_done
		);

	-- start on enable rising edge
	edge_inst_ena : entity work.edge(arch)
		port map(
			clk       => clk,
			rst       => rst,
			signal_in => ena,
			rising    => start,
			falling   => open
		);

	process (clk, rst) begin
		if rst = '0' then
			txt_cnt <= 0;
			state <= idle;
		elsif rising_edge(clk) then
			case state is
				when idle =>
					if start = '1' then
						busy <= '1';
						i2c_rw <= '0'; -- write
						i2c_in <= txt(txt_cnt); -- send first byte
						txt_cnt <= 1; -- next index is 1
						i2c_ena <= '1';
						state <= send;
					end if;

				when send =>
					if i2c_done = '1' then -- interface is ready for next byte
						if txt_cnt = txt_len then -- turn off i2c enable on the last byte
							txt_cnt <= 0;
							i2c_ena <= '0';
							state <= speak;
						else
							i2c_in <= txt(txt_cnt); -- from 1 to txt_len - 1
							txt_cnt <= txt_cnt + 1;
						end if;
					end if;

				when speak => -- read info until unprocessed buffer is zero
					i2c_rw <= '1'; -- read
					i2c_ena <= '1';
					info_cnt <= 0;
					state <= check;

				when check =>
					if i2c_done = '1' then
						if info_cnt = info_cnt'high then
							info_cnt <= 0;
							i2c_ena <= '0';
							if tts_info(0) & tts_info(1) = 0 then -- unprocessed buffer is zero
								busy <= '0';
								state <= idle;
							else
								state <= speak;
							end if;
						else
							tts_info(info_cnt) <= i2c_out;
							info_cnt <= info_cnt + 1;
						end if;
					end if;

			end case;
		end if;
	end process;

end arch;
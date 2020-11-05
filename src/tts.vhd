library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;

entity tts is
	generic (
		txt_len_max : integer := 16 -- maximum length of text
	);
	port (
		-- system
		clk, rst_n : in std_logic;
		-- tts
		tts_scl, tts_sda : inout std_logic;
		-- user logic
		ena     : in std_logic;
		busy    : out std_logic;
		txt     : in bytes_t(0 to txt_len_max - 1);
		txt_len : in integer range 1 to txt_len_max;

		dbg : out byte_t
	);
end tts;

architecture arch of tts is

	constant tts_addr : std_logic_vector(6 downto 0) := "0100000";

	-- state machine
	type tts_state_t is (idle, send, request_stat, get_stat);
	signal state : tts_state_t;

	signal start : std_logic; -- enable rising edge

	-- I2C wires/registers
	signal i2c_in : std_logic_vector(15 downto 0);
	signal i2c_out : std_logic_vector(7 downto 0);
	signal i2c_in_ena, i2c_out_ena : std_logic;
	signal i2c_in_cnt, i2c_out_cnt : integer range 0 to 2 ** 8 - 1;

	-- data count (in bytes)
	signal data_cnt : integer range 0 to txt_len_max;

	-- information read from tts
	-- 0, 1: number of unprocessed bytes in buffer (high byte, low byte)
	-- 2, 3: number of available space in buffer (high byte, low byte)
	-- 4: (MO2, MO1, MO0, delaying, playing, speaking, can't find firmware, can't open file), high active
	-- 5: (X, X, X, X, waiting for delay parameter, pausing, waiting for instant command parameter, waiting for normal command parameter), high active
	-- 6, 7: module version integral, module version decimal (e.g. 0x02 0x02 == v2.2)
	signal tts_info : bytes_t(0 to 7);

begin

	dbg <= reverse(to_unsigned(i2c_in_cnt, 8));

	i2c_inst : entity work.i2c(arch)
		generic map(
			bus_freq => 100_000
		)
		port map(
			clk             => clk,
			rst_n           => rst_n,
			scl             => tts_scl,
			sda             => tts_sda,
			data_in_wr_ena  => i2c_in_ena,
			data_out_rd_ena => i2c_out_ena,
			data_in_cnt     => i2c_in_cnt,
			data_out_cnt    => i2c_out_cnt,
			data_in         => i2c_in,
			data_out        => i2c_out
		);

	process (clk, rst_n) begin
		if rst_n = '0' then
			data_cnt <= 0;
			state <= idle;
			i2c_in_ena <= '0';
			i2c_out_ena <= '0';
		elsif rising_edge(clk) then
			-- default values
			i2c_in_ena <= '0';
			i2c_out_ena <= '0';

			case state is
				when idle =>
					if ena = '1' then
						busy <= '1';
						state <= send;
					else
						busy <= '0';
					end if;

				when send =>
					if i2c_in_cnt < i2c_in_cnt'high then
						i2c_in <= tts_addr & '0' & std_logic_vector(txt(data_cnt));
						i2c_in_ena <= '1';

						if data_cnt = txt_len - 1 then
							data_cnt <= 0;
							state <= request_stat;
						else
							data_cnt <= data_cnt + 1;
						end if;
					end if;

				when request_stat =>
					if i2c_in_cnt < i2c_in_cnt'high then
						i2c_in(15 downto 8) <= tts_addr & '1';
						i2c_in_ena <= '1';
						state <= get_stat;
					end if;

				when get_stat =>
					if i2c_out_cnt > 0 then
						if data_cnt = 8 then
							data_cnt <= 0;
							if tts_info(0) & tts_info(1) = 0 then
								state <= idle;
							else
								state <= request_stat;
							end if;
						else
							tts_info(data_cnt) <= unsigned(i2c_out);
							i2c_out_ena <= '1';
							data_cnt <= data_cnt + 1;
						end if;
					end if;
			end case;
		end if;
	end process;

end arch;

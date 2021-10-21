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
		tts_mo           : in unsigned(2 downto 0);
		tts_rst_n        : out std_logic;
		-- user logic
		ena     : in std_logic; -- start on enable rising edge
		busy    : out std_logic;
		txt     : in u8_arr_t(0 to txt_len_max - 1);
		txt_len : in integer range 0 to txt_len_max
	);
end tts;

architecture arch of tts is

	constant tts_addr : unsigned(6 downto 0) := "0100000";

	type tts_state_t is (idle, send, send_stop, wait_speech);
	signal state : tts_state_t;

	signal i2c_ena : std_logic;
	signal i2c_busy : std_logic;
	signal i2c_in : u8_t;

	signal start : std_logic;
	signal i2c_accepted : std_logic;
	signal i2c_done : std_logic;
	signal tts_done, tts_accepted : std_logic;

	signal txt_cnt : integer range 0 to txt_len_max - 1;

begin

	tts_rst_n <= rst_n;

	i2c_inst : entity work.i2c(arch)
		generic map(
			bus_freq => 100_000
		)
		port map(
			clk      => clk,
			rst_n    => rst_n,
			scl      => tts_scl,
			sda      => tts_sda,
			ena      => i2c_ena,
			busy     => i2c_busy,
			cmd      => tts_addr & '0',
			data_in  => i2c_in,
			data_out => open
		);

	edge_inst_i2c : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => i2c_busy,
			rising  => i2c_accepted,
			falling => i2c_done
		);

	edge_inst_ena : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => ena,
			rising  => start,
			falling => open
		);

	edge_inst_mo0 : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => tts_mo(0),
			rising  => tts_done,
			falling => tts_accepted
		);

	process (clk, rst_n) begin
		if rst_n = '0' then
			txt_cnt <= 0;
			busy <= '1';
			state <= idle;
		elsif rising_edge(clk) then
			case state is
				when idle =>
					if start = '1' then
						busy <= '1';
						i2c_in <= tts_set_mo; -- send first byte
						i2c_ena <= '1';
						state <= send;
					else
						busy <= '0';
					end if;

				when send =>
					if i2c_done = '1' then -- interface is ready for next byte
						if txt_cnt = 0 then
							i2c_in <= x"06"; -- set MO[2..0] = 110
						elsif txt_cnt >= 1 and txt_cnt <= txt_len then
							i2c_in <= txt(txt_cnt - 1);
						elsif txt_cnt = txt_len + 1 then
							i2c_in <= tts_set_mo;
						else
							i2c_in <= x"07"; -- set MO[2..0] = 111
						end if;

						if txt_cnt = txt_len + 2 then
							txt_cnt <= 0;
							state <= send_stop;
						else
							txt_cnt <= txt_cnt + 1;
						end if;
					end if;

				when send_stop =>
					if i2c_accepted = '1' then -- last byte sent to interface
						i2c_ena <= '0';
					end if;

					-- if i2c_done = '1' and tts_accepted = '1' then -- last byte transmission complete
					if i2c_done = '1' then -- last byte transmission complete
						state <= wait_speech;
					end if;

				when wait_speech =>
					if tts_done = '1' then
						state <= idle;
					end if;
			end case;
		end if;
	end process;

end arch;

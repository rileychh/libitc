library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package tts_p is
	type txt_t is array(integer range <>) of unsigned(7 downto 0);

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
			txt_len : in integer range 0 to txt_len_max
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
		ena     : in std_logic;
		busy    : out std_logic;
		txt     : in txt_t(0 to txt_len_max - 1);
		txt_len : in integer range 0 to txt_len_max
	);
end tts;

architecture arch of tts is

	constant tts_addr : unsigned(6 downto 0) := "0100000";

	type tts_state_t is (idle, send, stop);
	signal state : tts_state_t;

	signal i2c_ena : std_logic;
	signal i2c_busy : std_logic;
	signal i2c_rw : std_logic;
	signal i2c_in : unsigned(7 downto 0);
	signal i2c_out : unsigned(7 downto 0);
	signal i2c_accepted : std_logic;
	signal i2c_done : std_logic;

	signal txt_cnt : integer range 0 to txt_len_max - 1;

begin

	i2c_inst : entity work.i2c(arch)
		generic map(
			bus_freq => 100_000
		)
		port map(
			scl       => tts_scl,
			sda       => tts_sda,
			clk       => clk,
			rst       => rst,
			ena       => i2c_ena,
			busy      => i2c_busy,
			addr      => tts_addr,
			rw        => i2c_rw,
			data_in   => i2c_in,
			data_out  => i2c_out
		);

	edge_inst : entity work.edge(arch)
		port map(
			clk       => clk,
			rst       => rst,
			signal_in => i2c_busy,
			rising    => i2c_accepted,
			falling   => i2c_done
		);

	process (clk, rst) begin
		if rst = '0' then
			txt_cnt <= 0;
			state <= idle;
		elsif rising_edge(clk) then
			case state is
				when idle =>
					if ena = '1' then
						busy <= '1';
						i2c_rw <= '0'; -- write
						i2c_in <= txt(0); -- send first byte
						i2c_ena <= '1';
						txt_cnt <= 1; -- next index is 1
						state <= send;
					end if;

				when send =>
					if i2c_done = '1' then -- interface is ready for next byte
						i2c_in <= txt(txt_cnt);
						if txt_cnt = txt_len - 1 then
							txt_cnt <= 0;
							state <= stop;
						else
							txt_cnt <= txt_cnt + 1;
						end if;
					end if;

				when stop =>
					if i2c_accepted = '1' then -- last byte sent to interface
						i2c_ena <= '0';
					end if;

					if i2c_done = '1' then -- last byte transmission complete
						busy <= '0';
						state <= idle;
					end if;
			end case;
		end if;
	end process;

end arch;
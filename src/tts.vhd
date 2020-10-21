library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package tts_p is
	type txt_t is array(0 to 15) of unsigned(7 downto 0);
end package;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.tts_p.all;
use work.clk_p.all;
use work.i2c_p.all;

entity tts is
	port (
		-- tts
		tts_scl, tts_sda : inout std_logic;
		-- internal
		clk  : in std_logic;
		rst  : in std_logic;
		ena  : in std_logic;
		busy : out std_logic;
		txt  : in txt_t
	);
end tts;

architecture arch of tts is

	constant tts_addr : unsigned(6 downto 0) := to_unsigned(16#40#, 7);

	type tts_state_t is (idle, wake, send);
	signal state : tts_state_t;

	signal txt_reg : txt_t;

	signal i2c_clk : std_logic;
	signal i2c_ena : std_logic;
	signal i2c_busy : std_logic;
	signal i2c_rw : std_logic;
	signal i2c_rx : unsigned(7 downto 0);
	signal i2c_tx : unsigned(7 downto 0);

begin

	clk_sys_inst : entity work.clk_sys(arch)
		generic map(
			clk_out_freq => 200_000
		)
		port map(
			sys_clk => clk,
			sys_rst => rst,
			clk_out => i2c_clk
		);

	i2c_inst : entity work.i2c(arch)
		port map(
			scl  => tts_scl,
			sda  => tts_sda,
			clk  => i2c_clk,
			rst  => rst,
			ena  => i2c_ena,
			busy => i2c_busy,
			addr => tts_addr,
			rw   => i2c_rw,
			rx   => i2c_rx,
			tx   => i2c_tx
		);

	process (clk, rst) begin
		if rst = '0' then
			state <= idle;
		elsif rising_edge(clk) then
			case state is
				when idle =>
					if ena = '1' then
						txt_reg <= txt;
						state <= wake;
					end if;
				-- TODO complete this
				when wake =>

				when send =>
			end case;
		end if;
	end process;

end arch;
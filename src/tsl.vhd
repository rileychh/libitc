library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package tsl_p is
	component tsl
		port (
			-- tsl
			tsl_scl, tsl_sda : inout std_logic;
			-- system
			clk : in std_logic;
			rst : in std_logic;
			-- user logic
			lux : out integer range 0 to 40000 -- calculated illuminance from sensors
		);
	end component;
end package;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.clk_p.all;
use work.i2c_p.all;

entity tsl is
	port (
		-- tsl
		tsl_scl, tsl_sda : inout std_logic;
		-- system
		clk : in std_logic;
		rst : in std_logic;
		-- user logic
		lux : out integer range 0 to 40000 -- calculated illuminance from sensors
	);
end tsl;

architecture arch of tsl is

	-- TSL2561 I2C constants
	-- I2C writes to command register first: which is (cmd, clear, word, block, addr * 4)
	-- cmd means select command register. must be '1'
	-- clear is not used here. write '0'
	-- word is not used here. write '0'
	-- block means continuos reading/writing.
	-- addr means register address. for example, control register is at 0x0, id register is at 0xa
	constant tsl_addr : unsigned(6 downto 0) := "0111001"; -- device address (0x39)
	constant reg_ctrl : unsigned(7 downto 0) := x"80"; -- (write) byte to control register
	constant ctrl_power_on : unsigned(7 downto 0) := x"03"; -- power on command for control register
	constant reg_data_0 : unsigned(7 downto 0) := x"ac"; -- (read) word from data register 0
	constant reg_data_1 : unsigned(7 downto 0) := x"ae"; -- (read) word from data register 1

	-- state machines
	type tsl_state_t is (init, read_data_0, read_data_1);
	signal state : tsl_state_t;
	type i2c_step_t is (sel_reg, byte_0, byte_1);
	signal step : i2c_step_t;

	-- I2C wires/registers
	signal i2c_clk : std_logic;
	signal i2c_ena : std_logic;
	signal i2c_busy : std_logic;
	signal i2c_rw : std_logic;
	signal i2c_rx : unsigned(7 downto 0);
	signal i2c_tx : unsigned(7 downto 0);

	signal i2c_busy_prev : std_logic; -- register to store busy value from last clock
	signal i2c_done : std_logic; -- register to indicate transmission is done

	-- sensor values
	signal data_0 : unsigned(15 downto 0);
	signal data_1 : unsigned(15 downto 0);

	-- convert sensor values to lux reading
	-- see docs/lux.cpp
	function to_lux(data_0, data_1 : unsigned(15 downto 0)) return integer is

		constant lux_scale : integer := 14;
		constant ratio_scale : integer := 9;

		constant ch_scale : integer := 2 ** 4; -- scale (multiply) CH0 (d0) and CH1 (d1)
		constant ch0 : integer := to_integer(data_0 * ch_scale); -- scaled CH0 in integer
		constant ch1 : integer := to_integer(data_1 * ch_scale); -- scaled CH1 in integer
		constant ratio : integer := ((ch1 * (2 ** (ratio_scale + 1)) / ch0) + 1) / 2; -- rounded ratio between ch1 and ch0

		variable b : integer range 0 to 2 ** 10 - 1;
		variable m : integer range 0 to 2 ** 10 - 1;

	begin

		if ratio >= 0 and ratio <= 16#0040# then
			b := 16#01f2#;
			m := 16#01be#;
		elsif ratio <= 16#0080# then
			b := 16#0214#;
			m := 16#02d1#;
		elsif ratio <= 16#00c0# then
			b := 16#023f#;
			m := 16#037b#;
		elsif ratio <= 16#0100# then
			b := 16#0270#;
			m := 16#03fe#;
		elsif ratio <= 16#0138# then
			b := 16#016f#;
			m := 16#01fc#;
		elsif ratio <= 16#019a# then
			b := 16#00d2#;
			m := 16#00fb#;
		elsif ratio <= 16#029a# then
			b := 16#0018#;
			m := 16#0012#;
		elsif ratio > 16#029a# then
			b := 16#0000#;
			m := 16#0000#;
		end if;

		return ((ch0 * b - ch1 * m) + 2 ** (lux_scale - 1)) / 2 ** lux_scale;

	end function;

begin

	clk_inst : entity work.clk(arch)
		generic map(
			freq => 10
		)
		port map(
			clk_in => clk,
			rst => rst,
			clk_out => i2c_clk
		);

	i2c_inst : entity work.i2c(arch)
		port map(
			scl  => tsl_scl,
			sda  => tsl_sda,
			clk  => i2c_clk,
			rst  => rst,
			ena  => i2c_ena,
			busy => i2c_busy,
			addr => tsl_addr,
			rw   => i2c_rw,
			rx   => i2c_rx,
			tx   => i2c_tx
		);

	i2c_done <= i2c_busy_prev and not i2c_busy;

	process (clk, rst) begin
		if rst = '0' then
			lux <= 0;
			state <= init;
			step <= sel_reg;
		elsif rising_edge(clk) then
			i2c_busy_prev <= i2c_busy; -- update I2C busy flag

			case state is
				when init => -- turn power on
					case step is
						when sel_reg => -- select control register
							i2c_rw <= '0'; -- write
							i2c_tx <= reg_ctrl;
							i2c_ena <= '1'; -- start transmission

							if i2c_done = '1' then
								step <= byte_0; -- next step
							end if;
						when byte_0 => -- write power on to control register
							i2c_tx <= ctrl_power_on;

							if i2c_done = '1' then
								i2c_ena <= '0'; -- stop transmission
								step <= sel_reg; -- reset step
								state <= read_data_0; -- next state
							end if;
						when others => null; -- there's no second byte
					end case;

				when read_data_0 => -- read the ADC channel 0 value
					case step is
						when sel_reg =>
							i2c_rw <= '0'; -- write
							i2c_tx <= reg_data_0;
							i2c_ena <= '1';

							if i2c_done = '1' then
								step <= byte_0;
							end if;
						when byte_0 =>
							i2c_rw <= '1'; -- read

							if i2c_done = '1' then
								data_0(7 downto 0) <= i2c_rx; -- lower byte
								step <= byte_1;
							end if;
						when byte_1 =>
							if i2c_done = '1' then
								i2c_ena <= '0';
								data_0(15 downto 8) <= i2c_rx; -- upper byte
								step <= sel_reg;
								state <= read_data_1; -- read ADC channel 1
							end if;
					end case;

				when read_data_1 => -- read the ADC channel 1 value
					case step is
						when sel_reg =>
							i2c_rw <= '0'; -- write
							i2c_tx <= reg_data_1;
							i2c_ena <= '1';

							if i2c_done = '1' then
								step <= byte_0;
							end if;
						when byte_0 =>
							i2c_rw <= '0'; -- read

							if i2c_done = '1' then
								data_1(7 downto 0) <= i2c_rx; -- lower byte
								step <= byte_1;
							end if;
						when byte_1 =>
							if i2c_done = '1' then
								i2c_ena <= '0';
								data_1(15 downto 8) <= i2c_rx; -- upper byte
								step <= sel_reg;
								state <= read_data_0; -- back to reading ADC channel 0
								lux <= to_lux(data_0, data_1);
							end if;
					end case;
			end case;
		end if;
	end process;
end arch;
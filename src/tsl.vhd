library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package tsl_p is
	component tsl
		port (
			-- tsl
			tsl_scl : out std_logic;
			tsl_sda : inout std_logic;
			-- internal
			clk : in std_logic; -- 400kHz
			rst : in std_logic;
			lux : out integer -- calculated illuminance from sensors
		);
	end component;
end package;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.i2c_p.all;

entity tsl is

	port (
		-- tsl
		tsl_scl : out std_logic;
		tsl_sda : inout std_logic;
		-- internal
		clk : in std_logic; -- 800kHz
		rst : in std_logic;
		lux : out integer -- calculated illuminance from sensors
	);

end tsl;

architecture arch of tsl is

	-- TSL2561 I2C constants
	-- I2C writes to command register first: which is (cmd, clear, word, block, addr * 4)
	-- cmd means select command register. must be '1'
	-- clear is not used here. write '0'
	-- word is not used as well. write '0'
	-- block means continuos reading/writing.
	-- addr means register address. for example, control register is at 0x0, id register is at 0xa
	constant tsl_addr : unsigned(6 downto 0) := "0111001"; -- device address (0x39)
	constant reg_ctrl : unsigned(7 downto 0) := x"80"; -- select command, (write) byte to control register
	constant ctrl_power_on : unsigned(7 downto 0) := x"03"; -- power on command for control register
	constant reg_data_0 : unsigned(7 downto 0) := x"ac"; -- select command, (read) word from data register 0
	constant reg_data_1 : unsigned(7 downto 0) := x"ae"; -- select command, (read) word from data register 1

	-- state machines
	type tsl_state_t is (init, read_data_0, read_data_1);
	signal state : tsl_state_t;
	type i2c_state_t is (sel_reg, byte_0, byte_1);
	signal step : i2c_state_t;

	-- I2C wires/registers
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
	-- FIXME VHDL real type math has problems
	function to_lux(data_0, data_1 : unsigned(15 downto 0)) return integer is

		constant d0 : real := real(to_integer(data_0));
		constant d1 : real := real(to_integer(data_1));
		constant ratio : real := d1 / d0;

	begin

		if ratio < 0.5 then
			return integer(0.0304 * d0 - 0.0602 * d0 * ratio ** 1.4);
		elsif ratio < 0.61 then
			return integer(0.0224 * d0 - 0.031 * d1);
		elsif ratio < 0.80 then
			return integer(0.0128 * d0 - 0.0153 * d1);
		elsif ratio < 1.30 then
			return integer(0.0146 * d0 - 0.0112 * d1);
		else -- ratio > 1.30
			return 0;
		end if;

	end function;

begin

	i2c_inst : entity work.i2c(arch)
		port map(
			scl  => tsl_scl,
			sda  => tsl_sda,
			clk  => clk,
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
			state <= init;
			step <= sel_reg;
		elsif rising_edge(clk) then
			i2c_busy_prev <= i2c_busy; -- update I2C busy flag

			case state is
				when init => -- turn power on
					case step is
						when sel_reg => -- select control register
							i2c_rw <= write;
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
							i2c_rw <= write;
							i2c_tx <= reg_data_0;
							i2c_ena <= '1';

							if i2c_done = '1' then
								step <= byte_0;
							end if;
						when byte_0 =>
							i2c_rw <= read;

							if i2c_done = '1' then
								data_0(7 downto 0) <= i2c_rx; -- lower byte
								step <= byte_1;
							end if;
						when byte_1 =>
							if i2c_done = '1' then
								i2c_ena <= '0';
								step <= sel_reg;
								data_0(15 downto 8) <= i2c_rx; -- upper byte
								state <= read_data_1; -- read ADC channel 1
								step <= sel_reg;
							end if;
					end case;

				when read_data_1 => -- read the ADC channel 1 value
					case step is
						when sel_reg =>
							i2c_rw <= write;
							i2c_tx <= reg_data_1;
							i2c_ena <= '1';

							if i2c_done = '1' then
								step <= byte_0;
							end if;
						when byte_0 =>
							i2c_rw <= read;

							if i2c_done = '1' then
								data_1(7 downto 0) <= i2c_rx; -- lower byte
								step <= byte_1;
							end if;
						when byte_1 =>
							if i2c_done = '1' then
								i2c_ena <= '0';
								step <= sel_reg;
								data_1(15 downto 8) <= i2c_rx; -- upper byte
								state <= read_data_0; -- back to reading ADC channel 0
								step <= sel_reg;
							end if;
					end case;
			end case;
		end if;
	end process;

	lux <= to_lux(data_0, data_1);

end arch;
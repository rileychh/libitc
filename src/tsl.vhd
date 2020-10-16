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
			clk : in std_logic; -- 800kHz
			rst : in std_logic;
			lux : out integer; -- calculated illuminance from sensors
			-- debug
			dbg_i2c_state : out unsigned(2 downto 0)
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
		lux : out integer; -- calculated illuminance from sensors
		-- debug
		dbg_i2c_state : out unsigned(2 downto 0)
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

		constant lux_scale : integer := 14; -- scale by 2^14
		constant ratio_scale : integer := 9; -- scale ratio by 2^9
		--−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−
		-- T, FN, and CL Package coefficients
		--−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−
		-- For Ch1/Ch0=0.00 to 0.50
		-- Lux/Ch0=0.0304−0.062*((Ch1/Ch0)^1.4)
		-- piecewise approximation
		-- For Ch1/Ch0=0.00 to 0.125:
		-- Lux/Ch0=0.0304−0.0272*(Ch1/Ch0)
		--
		-- For Ch1/Ch0=0.125 to 0.250:
		-- Lux/Ch0=0.0325−0.0440*(Ch1/Ch0)
		--
		-- For Ch1/Ch0=0.250 to 0.375:
		-- Lux/Ch0=0.0351−0.0544*(Ch1/Ch0)
		--
		-- For Ch1/Ch0=0.375 to 0.50:
		-- Lux/Ch0=0.0381−0.0624*(Ch1/Ch0)
		--
		-- For Ch1/Ch0=0.50 to 0.61:
		-- Lux/Ch0=0.0224−0.031*(Ch1/Ch0)
		--
		-- For Ch1/Ch0=0.61 to 0.80:
		-- Lux/Ch0=0.0128−0.0153*(Ch1/Ch0)
		--
		-- For Ch1/Ch0=0.80 to 1.30:
		-- Lux/Ch0=0.00146−0.00112*(Ch1/Ch0)
		--
		-- For Ch1/Ch0>1.3:
		-- Lux/Ch0=0
		--−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−−
		constant k1 : integer := 16#0040#; -- 0.125 * 2^RATIO_SCALE
		constant b1 : integer := 16#01f2#; -- 0.0304 * 2^LUX_SCALE
		constant m1 : integer := 16#01be#; -- 0.0272 * 2^LUX_SCALE
		constant k2 : integer := 16#0080#; -- 0.250 * 2^RATIO_SCALE
		constant b2 : integer := 16#0214#; -- 0.0325 * 2^LUX_SCALE
		constant m2 : integer := 16#02d1#; -- 0.0440 * 2^LUX_SCALE
		constant k3 : integer := 16#00c0#; -- 0.375 * 2^RATIO_SCALE
		constant b3 : integer := 16#023f#; -- 0.0351 * 2^LUX_SCALE
		constant m3 : integer := 16#037b#; -- 0.0544 * 2^LUX_SCALE
		constant k4 : integer := 16#0100#; -- 0.50 * 2^RATIO_SCALE
		constant b4 : integer := 16#0270#; -- 0.0381 * 2^LUX_SCALE
		constant m4 : integer := 16#03fe#; -- 0.0624 * 2^LUX_SCALE
		constant k5 : integer := 16#0138#; -- 0.61 * 2^RATIO_SCALE
		constant b5 : integer := 16#016f#; -- 0.0224 * 2^LUX_SCALE
		constant m5 : integer := 16#01fc#; -- 0.0310 * 2^LUX_SCALE
		constant k6 : integer := 16#019a#; -- 0.80 * 2^RATIO_SCALE
		constant b6 : integer := 16#00d2#; -- 0.0128 * 2^LUX_SCALE
		constant m6 : integer := 16#00fb#; -- 0.0153 * 2^LUX_SCALE
		constant k7 : integer := 16#029a#; -- 1.3 * 2^RATIO_SCALE
		constant b7 : integer := 16#0018#; -- 0.00146 * 2^LUX_SCALE
		constant m7 : integer := 16#0012#; -- 0.00112 * 2^LUX_SCALE
		constant k8 : integer := 16#029a#; -- 1.3 * 2^RATIO_SCALE
		constant b8 : integer := 16#0000#; -- 0.000 * 2^LUX_SCALE
		constant m8 : integer := 16#0000#; -- 0.000 * 2^LUX_SCALE

		constant ch_scale : integer := 2 ** 4; -- scale (multiply) CH0 (d0) and CH1 (d1)
		constant ch0 : integer := to_integer(data_0 * ch_scale); -- scaled CH0 in integer
		constant ch1 : integer := to_integer(data_1 * ch_scale); -- scaled CH1 in integer
		constant ratio : integer := (ch1 * ((2 ** (ratio_scale + 1) / ch0)) + 1) / 2; -- rounded ratio between ch1 and ch0

		variable b : integer;
		variable m : integer;
		variable lux : integer;

	begin

		if ratio >= 0 and ratio <= k1 then
			b := b1;
			m := m1;
		elsif ratio <= k2 then
			b := b2;
			m := m2;
		elsif ratio <= k3 then
			b := b3;
			m := m3;
		elsif ratio <= k4 then
			b := b4;
			m := m4;
		elsif ratio <= k5 then
			b := b5;
			m := m5;
		elsif ratio <= k6 then
			b := b6;
			m := m6;
		elsif ratio <= k7 then
			b := b7;
			m := m7;
		elsif ratio > k8 then
			b := b8;
			m := m8;
		end if;

		lux := (ch0 * b) - (ch1 * m);
		if lux < 0 then
			lux := 0; -- don't allow negative values
		end if;
		-- round and strip off fractional portion
		lux := lux + 2 ** (lux_scale - 1);
		return lux / 2 ** lux_scale;

	end function;

begin

	i2c_inst : entity work.i2c(arch)
		port map(
			scl       => tsl_scl,
			sda       => tsl_sda,
			clk       => clk,
			rst       => rst,
			ena       => i2c_ena,
			busy      => i2c_busy,
			addr      => tsl_addr,
			rw        => i2c_rw,
			rx        => i2c_rx,
			tx        => i2c_tx,
			dbg_state => dbg_i2c_state
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
								data_0(15 downto 8) <= i2c_rx; -- upper byte
								step <= sel_reg;
								state <= read_data_1; -- read ADC channel 1
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
								data_1(15 downto 8) <= i2c_rx; -- upper byte
								step <= sel_reg;
								state <= read_data_0; -- back to reading ADC channel 0
							end if;
					end case;
			end case;
		end if;
	end process;

	lux <= to_lux(data_0, data_1);

end arch;
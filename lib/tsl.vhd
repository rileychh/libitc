library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;

entity tsl is
	port (
		-- tsl
		tsl_scl, tsl_sda : inout std_logic;
		-- system
		clk   : in std_logic;
		rst_n : in std_logic;
		-- user logic
		lux : out i16_t -- calculated illuminance from sensors
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
	constant reg_ctrl : u8_t := x"80"; -- (write) byte to control register
	constant ctrl_power_on : u8_t := x"03"; -- power on command for control register
	constant reg_data_0 : u8_t := x"ac"; -- (read) word from data register 0
	constant reg_data_1 : u8_t := x"ae"; -- (read) word from data register 1

	-- state machine
	type i2c_state_t is (reg, data);
	signal state : i2c_state_t;

	-- init register: turn power on only once
	signal init : std_logic;

	-- I2C wires/registers
	signal i2c_ena : std_logic;
	signal i2c_busy : std_logic;
	signal i2c_rw : std_logic;
	signal i2c_in : u8_t;
	signal i2c_out : u8_t;
	signal i2c_accepted : std_logic; -- indicates interface accepted data
	signal i2c_done : std_logic; -- indicates transmission is done

	-- sensor values
	signal reg_sel : integer range 0 to 3; -- select between ADC 0 and ADC 1
	signal data_0 : u16_t;
	signal data_1 : u16_t;

	-- convert sensor values to lux reading
	-- see docs/lux.cpp
	function to_lux(data_0, data_1 : u16_t) return integer is
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

	i2c_inst : entity work.i2c(arch)
		generic map(
			bus_freq => 400_000
		)
		port map(
			clk      => clk,
			rst_n    => rst_n,
			scl      => tsl_scl,
			sda      => tsl_sda,
			ena      => i2c_ena,
			busy     => i2c_busy,
			cmd      => tsl_addr & i2c_rw,
			data_in  => i2c_in,
			data_out => i2c_out
		);

	edge_inst : entity work.edge(arch) -- detect falling edge of i2c_busy
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => i2c_busy,
			rising  => i2c_accepted,
			falling => i2c_done
		);

	process (clk, rst_n) begin
		if rst_n = '0' then
			lux <= 0;
			init <= '0';
			state <= reg;
			reg_sel <= 0; -- read the first byte of data
		elsif rising_edge(clk) then
			if init = '0' then -- turn power on (setup)
				case state is
					when reg => -- select control register
						i2c_rw <= '0'; -- write
						i2c_in <= reg_ctrl;
						i2c_ena <= '1'; -- start transmission

						if i2c_done = '1' then -- register byte done
							i2c_in <= ctrl_power_on; -- continue with another write
							state <= data; -- next step
						end if;

					when data => -- write power on to control register
						if i2c_accepted = '1' then -- register byte accepted
							i2c_ena <= '0'; -- this is the last byte
						end if;

						if i2c_done = '1' then
							state <= reg; -- reset step
							init <= '1'; -- don't run init again
						end if;
				end case;
			else -- read the ADC channels' value (loop)
				case state is
					when reg => -- select data register
						i2c_rw <= '0'; -- write
						case reg_sel is
							when 0 | 1 =>
								i2c_in <= reg_data_0;
							when 2 | 3 =>
								i2c_in <= reg_data_1;
						end case;
						i2c_ena <= '1';

						if i2c_done = '1' then
							i2c_rw <= '1'; -- read
							state <= data;
						end if;

					when data =>
						if i2c_accepted = '1' then -- register byte accepted
							case reg_sel is
								when 0 | 2 => -- upper byte
									i2c_ena <= '1'; -- continue with another read
								when 1 | 3 => -- lower byte
									i2c_ena <= '0'; -- this is the last byte
							end case;
						end if;

						if i2c_done = '1' then
							case reg_sel is
								when 0 => -- ADC 0 lower byte
									data_0(7 downto 0) <= i2c_out;
								when 1 => -- ADC 0 upper byte
									data_0(15 downto 8) <= i2c_out;
									state <= reg;
								when 2 => -- ADC 1 lower byte
									data_1(7 downto 0) <= i2c_out;
								when 3 => -- ADC 1 upper byte
									data_1(15 downto 8) <= i2c_out;
									state <= reg;
									lux <= to_lux(data_0, data_1);
							end case;
							reg_sel <= reg_sel + 1;
						end if;
				end case;
			end if;
		end if;
	end process;
end arch;

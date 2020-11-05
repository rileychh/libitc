library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;

entity tsl is
	port (
		-- system
		clk, rst_n : in std_logic;
		-- tsl
		tsl_scl, tsl_sda : inout std_logic;
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
	constant tsl_addr : std_logic_vector(6 downto 0) := "0111001"; -- device address (0x39)
	constant reg_ctrl : std_logic_vector(7 downto 0) := x"80"; -- select control register
	constant ctrl_power_on : std_logic_vector(7 downto 0) := x"03"; -- power on command for control register
	constant reg_data_0 : std_logic_vector(7 downto 0) := x"ac"; -- (read) word from data register 0
	constant reg_data_1 : std_logic_vector(7 downto 0) := x"ae"; -- (read) word from data register 1

	-- state machine
	type tsl_state_t is (init, request_data, get_data);
	signal state : tsl_state_t;

	-- I2C wires/registers
	signal i2c_in : std_logic_vector(15 downto 0);
	signal i2c_out : std_logic_vector(7 downto 0);
	signal i2c_in_ena, i2c_out_ena : std_logic;
	signal i2c_in_cnt, i2c_out_cnt : integer range 0 to 2 ** 8 - 1;

	-- data count (in bytes)
	signal data_cnt : integer range 0 to 4;

	-- sensor values
	signal data_0 : unsigned(15 downto 0);
	signal data_1 : unsigned(15 downto 0);

	-- convert sensor values to lux reading
	-- see docs/lux.cpp
	function get_lux(data_0, data_1 : unsigned(15 downto 0)) return integer is
		constant lux_scale : integer := 14;
		constant ratio_scale : integer := 9;

		constant ch_scale : integer := 2 ** 4; -- scale (multiply) CH0 (d0) and CH1 (d1): 402ms integration time and 1x gain
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
			clk             => clk,
			rst_n           => rst_n,
			scl             => tsl_scl,
			sda             => tsl_sda,
			data_in_wr_ena  => i2c_in_ena,
			data_out_rd_ena => i2c_out_ena,
			data_in_cnt     => i2c_in_cnt,
			data_out_cnt    => i2c_out_cnt,
			data_in         => i2c_in,
			data_out        => i2c_out
		);

	process (clk, rst_n) begin
		if rst_n = '0' then
			lux <= 0;
			state <= init;
		elsif rising_edge(clk) then
			-- default values
			i2c_in_ena <= '0';
			i2c_out_ena <= '0';

			case state is
				when init =>
					if i2c_in_cnt < i2c_in_cnt'high then
						if data_cnt = 2 then
							data_cnt <= 0;
							state <= request_data;
						else
							case data_cnt is
								when 0 =>
									i2c_in <= tsl_addr & '0' & reg_ctrl;
								when 1 =>
									i2c_in <= tsl_addr & '0' & ctrl_power_on;
								when others => null;
							end case;
							i2c_in_ena <= '1';

							data_cnt <= data_cnt + 1;
						end if;
					end if;

				when request_data =>
					if i2c_in_cnt < i2c_in_cnt'high then
						if data_cnt = 4 then
							data_cnt <= 0;
							state <= get_data;
							lux <= get_lux(data_0, data_1);
						else
							case data_cnt is
								when 0 =>
									i2c_in <= tsl_addr & '0' & reg_data_0;
								when 2 =>
									i2c_in <= tsl_addr & '0' & reg_data_1;
								when 1 | 3 =>
									i2c_in(15 downto 8) <= tsl_addr & '1';
								when others => null;
							end case;
							i2c_in_ena <= '1';

							data_cnt <= data_cnt + 1;
						end if;
					end if;

				when get_data =>
					if i2c_out_cnt > 0 then
						if data_cnt = 4 then
							data_cnt <= 0;
							state <= request_data;
						else
							case data_cnt is
								when 0 =>
									data_0(15 downto 8) <= unsigned(i2c_out);
								when 1 =>
									data_0(7 downto 0) <= unsigned(i2c_out);
								when 2 =>
									data_1(15 downto 8) <= unsigned(i2c_out);
								when 3 =>
									data_1(7 downto 0) <= unsigned(i2c_out);
								when others => null;
							end case;
							i2c_out_ena <= '1';

							data_cnt <= data_cnt + 1;
						end if;
					end if;
			end case;
		end if;
	end process;
end arch;

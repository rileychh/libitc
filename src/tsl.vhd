library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.i2c_p.all;

entity tsl is

	port (
		-- tsl
		tsl_scl : out std_logic;
		tsl_sda : inout std_logic;
		-- internal
		clk : in std_logic; -- 400kHz
		rst : in std_logic;
		lux : out integer -- calculated illuminance from sensors
	);

end tsl;

architecture arch of tsl is

	-- TSL2561 I2C constants
	constant tsl_addr : unsigned(7 downto 0) := x"39"; -- device address
	constant tsl_cmd : unsigned(7 downto 0) := x"80"; -- command register, where I2C writes to, (4 downto 0) is other register's address
	constant reg_ctrl : unsigned(7 downto 0) := x"00"; -- control register, controls power
	constant reg_data_0 : unsigned(7 downto 0) := x"0c"; -- ADC channel 0, 2 bytes
	constant reg_data_1 : unsigned(7 downto 0) := x"0e"; -- ADC channel 1, 2 bytes

	-- state machines
	type tsl_state_t is (init, init_wait, read, read_wait);
	signal state : tsl_state_t;

	-- I2C wires
	signal i2c_ena : std_logic;
	signal i2c_busy : std_logic;
	signal i2c_reg_addr : unsigned(7 downto 0);
	signal i2c_rw : std_logic;
	signal i2c_rx : byte_arr(0 to 1);
	signal i2c_tx : byte_arr(0 to 1);
	signal i2c_data_len : integer range 1 to 2;

	-- sensor values
	signal data_0 : unsigned(15 downto 0);
	signal data_1 : unsigned(15 downto 0);

begin

	i2c_reg_inst : entity work.i2c_reg(arch)
		generic map(
			data_len_max => 2
		)
		port map(
			scl      => tsl_scl,
			sda      => tsl_sda,
			clk      => clk,
			rst      => rst,
			ena      => i2c_ena,
			busy     => i2c_busy,
			dev_addr => tsl_addr,
			rw       => i2c_rw,
			reg_addr => i2c_reg_addr,
			rx       => i2c_rx,
			tx       => i2c_tx,
			data_len => i2c_data_len
		);

	process (clk)

		variable cnt : integer range 0 to 1;

	begin
		if rst = '0' then
			state <= init;
		elsif rising_edge(clk) then
			case state is
				when init => -- write 0x03 to control register, which means power on
					i2c_rw <= '0';
					i2c_reg_addr <= reg_ctrl or tsl_cmd;
					i2c_tx(0) <= x"03";
					i2c_data_len <= 1;
					i2c_ena <= '1';
					state <= init_wait;
				when init_wait => -- wait for transfer to complete
					if i2c_busy = '0' then
						i2c_ena <= '0';
						cnt := 0; -- prepare cnt for reading
						state <= read;
					end if;
				when read => -- read the two sensors' values
					i2c_rw <= '1'; -- read
					case cnt is -- decide register based on count
						when 0 => i2c_reg_addr <= reg_data_0 or tsl_cmd;
						when 1 => i2c_reg_addr <= reg_data_1 or tsl_cmd;
					end case;
					i2c_data_len <= 2;
					i2c_ena <= '1';
					state <= read_wait;
				when read_wait => -- wait for transfer to complete
					if i2c_busy = '0' then
						i2c_ena <= '0';
						case cnt is -- decide register based on count
							when 0 => data_0 <= i2c_rx(1) & i2c_rx(0); -- concatenate higher byte (second byte) and lower byte (first byte)
							when 1 => data_1 <= i2c_rx(1) & i2c_rx(0);
						end case;
						cnt := cnt + 1; -- swap register address
						state <= read; -- loop back to reading state
					end if;
			end case;
		end if;
	end process;

end arch;
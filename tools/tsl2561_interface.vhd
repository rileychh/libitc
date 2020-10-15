--
-- Simple TSL2561 driver; supports only a single TSL2561 at a time.
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tsl2561_interface is
  generic (

    --This is the address for a floating ADDR SEL pin.
    --If the ADDR SEL pin is tied high, provide "1001001" instead.
    --If the ADDR SEL pin is tied low, provide  "0101001" instead.
    address : std_logic_vector(6 downto 0) := "0111001";

    --The clock frequency of the board you're using.
    --For the Basys board, this is usually 50MHz, or 50_000_000.
    clk_frequency : integer := 50_000_000;

    --The I2C clock frequency. This can be any number below 400kHz for
    --the TSL2561.
    i2c_frequency : integer := 100_000

  );
  port (

    --System clock.
    clk   : in std_logic;
    reset : in std_logic := '0';

    --I2C signals.
    sda : inout std_logic;
    scl : inout std_logic;

    --Light sensor reading...
    light_intensity : out std_logic_vector(15 downto 0)
  );
end tsl2561_interface;

architecture Behavioral of tsl2561_interface is
  --Signals for data exchange with the core I2C controller.
  signal data_to_write, last_read_data : std_logic_vector(7 downto 0);
  signal read_or_write, transaction_active, controller_in_use : std_logic;

  --Rising edge detect for the "controller in use" signal.
  --A rising edge of this signal indicates that the I2C controller has accepted our data.
  signal controller_was_in_use : std_logic;
  signal controller_accepted_data : std_logic;

  --I2C read/write constants.
  constant write : std_logic := '0';
  constant read : std_logic := '1';

  --TSL2561 commands.
  constant select_control_register : std_logic_vector := x"80";
  constant power_on : std_logic_vector := x"03";
  constant read_light_intensity : std_logic_vector := x"AC";
  --Core state machine logic for the 
  type state_type is (STARTUP, SEND_POWER_COMMAND, TURN_POWER_ON,
    WAIT_BEFORE_READING, SEND_READ_COMMAND, READ_LOW_BYTE, READ_HIGH_BYTE);
  signal state, next_state : state_type := STARTUP;
begin

  --
  -- Instantiate our I2C controller.
  --
  I2C_CONTROLLER :
  entity i2c_master
    generic map(
      input_clk => 50_000_000, --Our system clock speed, 50MHz.
      bus_clk   => 100_000
    )
    port map(
      clk       => clk,
      reset_n   => not reset,
      ena       => transaction_active,
      addr      => address,
      rw        => read_or_write,
      data_wr   => data_to_write,
      busy      => controller_in_use,
      data_rd   => last_read_data,
      ack_error => open,
      sda       => sda,
      scl       => scl
    );

    --
    -- Rising edge detect for the I2C controller's "in use" signal.
    --
    -- A rising edge of this signal denotes that the controller has accepted our data,
    -- and allows progression of our FSM.
    --
    controller_was_in_use <= controller_in_use when rising_edge(clk);
    controller_accepted_data <= controller_in_use and not controller_was_in_use;

    CONTROL_FSM :
    process (clk)
    begin

      -- If our reset signal is being driven, restar the FSM.
      if reset = '1' then
        state <= state_type'left;

      elsif rising_edge(clk) then

        --Keep the following signals low unless asserted.
        --(This also prevents us from inferring additional memory.)
        data_to_write <= (others => '0');

        case state is

            --
            -- Wait state.
            -- Waits for the I2C controller to become ready.
            --
          when STARTUP =>

            if controller_in_use = '0' then
              state <= SEND_POWER_COMMAND;
            end if;

            --
            -- First power-on state.
            -- Sets up the initial I2C communication that will enable the device's internal ADC.
            --
          when SEND_POWER_COMMAND =>

            --Set up the device to write the first byte of the setup command.
            transaction_active <= '1';
            read_or_write <= write;

            --Select the device's primary control register.
            data_to_write <= select_control_register;

            --Wait here for the I2C controller to accept the new transmission, and become busy.
            if controller_accepted_data = '1' then
              state <= TURN_POWER_ON;
            end if;

            --
            -- Second power-on state.
            -- Continues the ADC enable communication.
            --
          when TURN_POWER_ON =>

            --And turn the device's enable on.
            data_to_write <= power_on;

            --Once the controller has accepted this data,
            --move to the core sensor reading routine.
            if controller_accepted_data = '1' then
              state <= WAIT_BEFORE_READING;
            end if;
            --
            -- Wait for the transmitter to become ready
            -- before starting a second TWI transaction.
            --
          when WAIT_BEFORE_READING =>

            --Ensure we are not transmitting during for a
            --least a short period between readings.
            transaction_active <= '0';

            --Wait for the transmitter to become idle.
            if controller_in_use = '0' then

              --In most cases, we've just come from the READ_HIGH_BYTE state,
              --and the last read data is the correct high byte of our light intensity.
              --(If we've just started up, we'll produce one cycle of gargage; but this
              -- shouldn't affect any designs. If this affects yours, you'll need to
              -- create a duplicate of this state which is only reached after a successful
              -- reading.)
              light_intensity(15 downto 8) <= last_read_data;

              state <= SEND_READ_COMMAND;
            end if;
            --
            -- Send the "read" command.
            -- This sets up a multi-byte read from the ADC sample register.
            --
          when SEND_READ_COMMAND =>

            --Set up the device to write to the command register,
            --indicating that we want to read multiple bytes from the ADC register.
            transaction_active <= '1';
            read_or_write <= write;

            --Select the device's primary control register.
            data_to_write <= read_light_intensity;

            --Once the controller has accepted the command,
            --move to the state where we'll read from the device itself.
            if controller_accepted_data = '1' then
              state <= READ_LOW_BYTE;
            end if;
            --
            -- Read the ADC low byte.
            -- This reads the low byte of the ADC.
            --
          when READ_LOW_BYTE =>

            --Set up the device to write to the command register,
            --indicating that we want to read multiple bytes from the ADC register.
            transaction_active <= '1';
            read_or_write <= read;

            --Once the controller has initiated the read
            --move to read the subsequent bit.
            if controller_accepted_data = '1' then
              state <= READ_HIGH_BYTE;
            end if;
            --
            -- Read the ADC low byte.
            -- This reads the low byte of the ADC.
            --
          when READ_HIGH_BYTE =>

            --If the controller has gone idle, the most recently read data
            --will be the data read in the last state; or the ADC low byte.
            if controller_in_use = '0' then
              light_intensity(7 downto 0) <= last_read_data;
            end if;

            --Once the controller has accepted the data,
            if controller_accepted_data = '1' then
              state <= WAIT_BEFORE_READING;
            end if;
        end case;
      end if;
    end process;
  end Behavioral;
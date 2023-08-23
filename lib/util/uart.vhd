library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;

entity uart is
	generic (
		baud : integer := 9_600 -- data link baud rate in bits/second
	);

	port (
		-- system
		clk, rst_n : in std_logic;
		-- uart
		uart_rx : in std_logic;  -- receive pin
		uart_tx : out std_logic; -- transmit pin
		-- user logic
		tx_ena  : in std_logic;  -- initiate transmission
		tx_busy : out std_logic; -- transmission in progress
		tx_data : in u8_t;       -- data to transmit
		rx_busy : out std_logic; -- data reception in progress
		rx_err  : out std_logic; -- start, parity, or stop bit error detected
		rx_data : out u8_t       -- data received
	);
end uart;

architecture arch of uart is

	constant os_rate : integer := 16; -- oversampling rate to find center of receive bits (in samples per baud period)

	type state_t is (idle, execute); -- state machine data type
	signal rx_state, tx_state : state_t; -- receive and transmit state machine

	signal baud_pulse : std_logic := '0'; -- periodic pulse that occurs at the baud rate
	signal os_pulse : std_logic := '0'; -- periodic pulse that occurs at the oversampling rate

	signal rx_buffer : unsigned(8 downto 0);
	signal tx_buffer : unsigned(9 downto 0);

begin

	-- generate clock enable pulses at the baud rate and the oversampling rate
	process (clk, rst_n)
		variable count_baud : integer range 0 to sys_clk_freq / baud - 1 := 0; -- counter to determine baud rate period
		variable count_os : integer range 0 to sys_clk_freq / baud / os_rate - 1 := 0; -- counter to determine oversampling period
	begin
		if rst_n = '0' then -- asynchronous reset asserted
			baud_pulse <= '0'; -- reset baud rate pulse
			os_pulse <= '0'; -- reset oversampling rate pulse
			count_baud := 0; -- reset baud period counter
			count_os := 0; -- reset oversampling period counter
		elsif rising_edge(clk) then
			-- create baud enable pulse
			if count_baud < count_baud'high then -- baud period not reached
				count_baud := count_baud + 1; -- increment baud period counter
				baud_pulse <= '0'; -- deassert baud rate pulse
			else -- baud period reached
				count_baud := 0; -- reset baud period counter
				count_os := 0; -- reset oversampling period counter to avoid cumulative error
				baud_pulse <= '1'; -- assert baud rate pulse
			end if;
			-- create oversampling enable pulse
			if count_os < count_os'high then -- oversampling period not reached
				count_os := count_os + 1; -- increment oversampling period counter
				os_pulse <= '0'; -- deassert oversampling rate pulse		
			else -- oversampling period reached
				count_os := 0; -- reset oversampling period counter
				os_pulse <= '1'; -- assert oversampling pulse
			end if;
		end if;
	end process;

	-- receive state machine
	process (clk, rst_n, os_pulse)
		variable rx_count : integer range 0 to 8 + 2 := 0; -- count the bits received
		variable os_count : integer range 0 to os_rate - 1 := 0; -- count the oversampling rate pulses
	begin
		if rst_n = '0' then -- asynchronous reset asserted
			os_count := 0; -- clear oversampling pulse counter
			rx_count := 0; -- clear receive bit counter
			rx_busy <= '0'; -- clear receive busy signal
			rx_err <= '0'; -- clear receive errors
			rx_data <= (others => '0'); -- clear received data output
			rx_state <= idle; -- put in idle state
		elsif rising_edge(clk) and os_pulse = '1' then -- enable clock at oversampling rate
			case rx_state is
				when idle => -- idle state
					rx_busy <= '0'; -- clear receive busy flag
					if uart_rx = '0' then -- start bit might be present
						if os_count < os_rate / 2 then -- oversampling pulse counter is not at start bit center
							os_count := os_count + 1; -- increment oversampling pulse counter
							rx_state <= idle; -- remain in idle state
						else -- oversampling pulse counter is at bit center
							os_count := 0; -- clear oversampling pulse counter
							rx_count := 0; -- clear the bits received counter
							rx_busy <= '1'; -- assert busy flag
							rx_state <= execute; -- advance to receive state
						end if;
					else -- start bit not present
						os_count := 0; -- clear oversampling pulse counter
						rx_state <= idle; -- remain in idle state
					end if;
				when execute => -- receive state
					if os_count < os_rate - 1 then -- not center of bit
						os_count := os_count + 1; -- increment oversampling pulse counter
						rx_state <= execute; -- remain in receive state
					elsif rx_count < 8 then -- center of bit and not all bits received
						os_count := 0; -- reset oversampling pulse counter		
						rx_count := rx_count + 1; -- increment number of bits received counter
						rx_buffer <= uart_rx & rx_buffer(8 downto 1); -- shift new received bit into receive buffer
						rx_state <= execute; -- remain in receive state
					else -- center of stop bit
						rx_data <= rx_buffer(8 downto 1); -- output data received to user logic
						rx_err <= rx_buffer(0) or not uart_rx; -- output start, parity, and stop bit error flag
						rx_busy <= '0'; -- deassert received busy flag
						rx_state <= idle; -- return to idle state
					end if;
			end case;
		end if;
	end process;

	-- transmit state machine
	process (clk, rst_n)
		variable tx_count : integer range 0 to 8 + 3 := 0; -- count bits transmitted
	begin
		if rst_n = '0' then -- asynchronous reset asserted
			tx_count := 0; -- clear transmit bit counter
			uart_tx <= '1'; -- set tx pin to idle value of high
			tx_busy <= '1'; -- set transmit busy signal to indicate unavailable
			tx_state <= idle; -- set tx state machine to ready state
		elsif rising_edge(clk) then
			case tx_state is
				when idle => -- idle state
					if tx_ena = '1' then -- new transaction latched in
						tx_buffer(9 downto 0) <= tx_data & '0' & '1'; -- latch in data for transmission and start/stop bits
						tx_busy <= '1'; -- assert transmit busy flag
						tx_count := 0; -- clear transmit bit count
						tx_state <= execute; -- proceed to transmit state
					else -- no new transaction initiated
						tx_busy <= '0'; -- clear transmit busy flag
						tx_state <= idle; -- remain in idle state
					end if;
				when execute => -- transmit state
					if baud_pulse = '1' then -- beginning of bit
						tx_count := tx_count + 1; -- increment transmit bit counter
						tx_buffer <= '1' & tx_buffer(9 downto 1); -- shift transmit buffer to output next bit
					end if;
					if tx_count < 8 + 3 then -- not all bits transmitted
						tx_state <= execute; -- remain in transmit state
					else -- all bits transmitted
						tx_state <= idle; -- return to idle state
					end if;
			end case;
			uart_tx <= tx_buffer(0); -- output last bit in transmit transaction buffer
		end if;
	end process;

end arch;

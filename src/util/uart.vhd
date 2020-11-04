--------------------------------------------------------------------------------
--
--   FileName:         uart.vhd
--   Dependencies:     none
--   Design Software:  Quartus II 64-bit Version 13.1.0 Build 162 SJ Web Edition
--
--   HDL CODE IS PROVIDED "AS IS."  DIGI-KEY EXPRESSLY DISCLAIMS ANY
--   WARRANTY OF ANY KIND, WHETHER EXPRESS OR IMPLIED, INCLUDING BUT NOT
--   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
--   PARTICULAR PURPOSE, OR NON-INFRINGEMENT. IN NO EVENT SHALL DIGI-KEY
--   BE LIABLE FOR ANY INCIDENTAL, SPECIAL, INDIRECT OR CONSEQUENTIAL
--   DAMAGES, LOST PROFITS OR LOST DATA, HARM TO YOUR EQUIPMENT, COST OF
--   PROCUREMENT OF SUBSTITUTE GOODS, TECHNOLOGY OR SERVICES, ANY CLAIMS
--   BY THIRD PARTIES (INCLUDING BUT NOT LIMITED TO ANY DEFENSE THEREOF),
--   ANY CLAIMS FOR INDEMNITY OR CONTRIBUTION, OR OTHER SIMILAR COSTS.
--
--   Version History
--   Version 1.0 5/26/2017 Scott Larson
--     Initial Public Release
--    
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity uart_eewiki is
	generic (
		clk_freq  : integer   := 50_000_000; --frequency of system clock in Hertz
		baud_rate : integer   := 19_200;     --data link baud rate in bits/second
		os_rate   : integer   := 16;         --oversampling rate to find center of receive bits (in samples per baud period)
		d_width   : integer   := 8;          --data bus width
		parity    : integer   := 1;          --0 for no parity, 1 for parity
		parity_eo : std_logic := '0');       --'0' for even, '1' for odd parity
	port (
		clk      : in std_logic;                               --system clock
		reset_n  : in std_logic;                               --ascynchronous reset
		tx_ena   : in std_logic;                               --initiate transmission
		tx_data  : in std_logic_vector(d_width - 1 downto 0);  --data to transmit
		rx       : in std_logic;                               --receive pin
		rx_busy  : out std_logic;                              --data reception in progress
		rx_error : out std_logic;                              --start, parity, or stop bit error detected
		rx_data  : out std_logic_vector(d_width - 1 downto 0); --data received
		tx_busy  : out std_logic;                              --transmission in progress
		tx       : out std_logic);                             --transmit pin
end uart_eewiki;

architecture logic of uart_eewiki is
	type tx_machine is(idle, transmit); --tranmit state machine data type
	type rx_machine is(idle, receive); --receive state machine data type
	signal tx_state : tx_machine; --transmit state machine
	signal rx_state : rx_machine; --receive state machine
	signal baud_pulse : std_logic := '0'; --periodic pulse that occurs at the baud rate
	signal os_pulse : std_logic := '0'; --periodic pulse that occurs at the oversampling rate
	signal parity_error : std_logic; --receive parity error flag
	signal rx_parity : std_logic_vector(d_width downto 0); --calculation of receive parity
	signal tx_parity : std_logic_vector(d_width downto 0); --calculation of transmit parity
	signal rx_buffer : std_logic_vector(parity + d_width downto 0) := (others => '0'); --values received
	signal tx_buffer : std_logic_vector(parity + d_width + 1 downto 0) := (others => '1'); --values to be transmitted
begin

	--generate clock enable pulses at the baud rate and the oversampling rate
	process (reset_n, clk)
		variable count_baud : integer range 0 to clk_freq/baud_rate - 1 := 0; --counter to determine baud rate period
		variable count_os : integer range 0 to clk_freq/baud_rate/os_rate - 1 := 0; --counter to determine oversampling period
	begin
		if (reset_n = '0') then --asynchronous reset asserted
			baud_pulse <= '0'; --reset baud rate pulse
			os_pulse <= '0'; --reset oversampling rate pulse
			count_baud := 0; --reset baud period counter
			count_os := 0; --reset oversampling period counter
		elsif (clk'EVENT and clk = '1') then
			--create baud enable pulse
			if (count_baud < clk_freq/baud_rate - 1) then --baud period not reached
				count_baud := count_baud + 1; --increment baud period counter
				baud_pulse <= '0'; --deassert baud rate pulse
			else --baud period reached
				count_baud := 0; --reset baud period counter
				baud_pulse <= '1'; --assert baud rate pulse
				count_os := 0; --reset oversampling period counter to avoid cumulative error
			end if;
			--create oversampling enable pulse
			if (count_os < clk_freq/baud_rate/os_rate - 1) then --oversampling period not reached
				count_os := count_os + 1; --increment oversampling period counter
				os_pulse <= '0'; --deassert oversampling rate pulse		
			else --oversampling period reached
				count_os := 0; --reset oversampling period counter
				os_pulse <= '1'; --assert oversampling pulse
			end if;
		end if;
	end process;

	--receive state machine
	process (reset_n, clk)
		variable rx_count : integer range 0 to parity + d_width + 2 := 0; --count the bits received
		variable os_count : integer range 0 to os_rate - 1 := 0; --count the oversampling rate pulses
	begin
		if (reset_n = '0') then --asynchronous reset asserted
			os_count := 0; --clear oversampling pulse counter
			rx_count := 0; --clear receive bit counter
			rx_busy <= '0'; --clear receive busy signal
			rx_error <= '0'; --clear receive errors
			rx_data <= (others => '0'); --clear received data output
			rx_state <= idle; --put in idle state
		elsif (clk'EVENT and clk = '1' and os_pulse = '1') then --enable clock at oversampling rate
			case rx_state is
				when idle => --idle state
					rx_busy <= '0'; --clear receive busy flag
					if (rx = '0') then --start bit might be present
						if (os_count < os_rate/2) then --oversampling pulse counter is not at start bit center
							os_count := os_count + 1; --increment oversampling pulse counter
							rx_state <= idle; --remain in idle state
						else --oversampling pulse counter is at bit center
							os_count := 0; --clear oversampling pulse counter
							rx_count := 0; --clear the bits received counter
							rx_busy <= '1'; --assert busy flag
							rx_state <= receive; --advance to receive state
						end if;
					else --start bit not present
						os_count := 0; --clear oversampling pulse counter
						rx_state <= idle; --remain in idle state
					end if;
				when receive => --receive state
					if (os_count < os_rate - 1) then --not center of bit
						os_count := os_count + 1; --increment oversampling pulse counter
						rx_state <= receive; --remain in receive state
					elsif (rx_count < parity + d_width) then --center of bit and not all bits received
						os_count := 0; --reset oversampling pulse counter		
						rx_count := rx_count + 1; --increment number of bits received counter
						rx_buffer <= rx & rx_buffer(parity + d_width downto 1); --shift new received bit into receive buffer
						rx_state <= receive; --remain in receive state
					else --center of stop bit
						rx_data <= rx_buffer(d_width downto 1); --output data received to user logic
						rx_error <= rx_buffer(0) or parity_error or not rx; --output start, parity, and stop bit error flag
						rx_busy <= '0'; --deassert received busy flag
						rx_state <= idle; --return to idle state
					end if;
			end case;
		end if;
	end process;

	--receive parity calculation logic
	rx_parity(0) <= parity_eo;
	rx_parity_logic : for i in 0 to d_width - 1 generate
		rx_parity(i + 1) <= rx_parity(i) xor rx_buffer(i + 1);
	end generate;
	with parity select --compare calculated parity bit with received parity bit to determine error
		parity_error <= rx_parity(d_width) xor rx_buffer(parity + d_width) when 1, --using parity
		'0' when others; --not using parity

	--transmit state machine
	process (reset_n, clk)
		variable tx_count : integer range 0 to parity + d_width + 3 := 0; --count bits transmitted
	begin
		if (reset_n = '0') then --asynchronous reset asserted
			tx_count := 0; --clear transmit bit counter
			tx <= '1'; --set tx pin to idle value of high
			tx_busy <= '1'; --set transmit busy signal to indicate unavailable
			tx_state <= idle; --set tx state machine to ready state
		elsif (clk'EVENT and clk = '1') then
			case tx_state is
				when idle => --idle state
					if (tx_ena = '1') then --new transaction latched in
						tx_buffer(d_width + 1 downto 0) <= tx_data & '0' & '1'; --latch in data for transmission and start/stop bits
						if (parity = 1) then --if parity is used
							tx_buffer(parity + d_width + 1) <= tx_parity(d_width); --latch in parity bit from parity logic
						end if;
						tx_busy <= '1'; --assert transmit busy flag
						tx_count := 0; --clear transmit bit count
						tx_state <= transmit; --proceed to transmit state
					else --no new transaction initiated
						tx_busy <= '0'; --clear transmit busy flag
						tx_state <= idle; --remain in idle state
					end if;
				when transmit => --transmit state
					if (baud_pulse = '1') then --beginning of bit
						tx_count := tx_count + 1; --increment transmit bit counter
						tx_buffer <= '1' & tx_buffer(parity + d_width + 1 downto 1); --shift transmit buffer to output next bit
					end if;
					if (tx_count < parity + d_width + 3) then --not all bits transmitted
						tx_state <= transmit; --remain in transmit state
					else --all bits transmitted
						tx_state <= idle; --return to idle state
					end if;
			end case;
			tx <= tx_buffer(0); --output last bit in transmit transaction buffer
		end if;
	end process;

	--transmit parity calculation logic
	tx_parity(0) <= parity_eo;
	tx_parity_logic : for i in 0 to d_width - 1 generate
		tx_parity(i + 1) <= tx_parity(i) xor tx_data(i);
	end generate;

end logic;
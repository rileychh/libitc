library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;

entity uart_txt is
	generic (
		txt_len_max : integer := 16;
		baud        : integer := 9_600 -- data link baud rate in bits/second
	);

	port (
		-- system
		clk, rst_n : in std_logic;
		-- uart
		uart_rx : in std_logic;  -- receive pin
		uart_tx : out std_logic; -- transmit pin
		-- user logic
		tx_ena  : in std_logic;                -- initiate transmission
		tx_busy : out std_logic;               -- transmission in progress
		tx_data : in string(1 to txt_len_max); -- data to transmit
		tx_len  : in integer range tx_data'range;
		rx_busy : out std_logic;                -- data reception in progress
		rx_data : out string(1 to txt_len_max); -- data received
		rx_len  : out integer range rx_data'range
	);
end uart_txt;

architecture arch of uart_txt is

	signal uart_tx_ena, uart_tx_busy, uart_rx_busy, uart_rx_err : std_logic;
	signal uart_tx_data_i : u8_t;
	signal uart_tx_data : character;
	signal uart_rx_data_i : u8_t;
	signal uart_rx_data : character;
	signal uart_tx_done : std_logic;
	signal uart_rx_done : std_logic;

	type state_t is (idle, execute);
	signal tx_state, rx_state : state_t;

	signal tx_cnt, rx_cnt : integer range 0 to txt_len_max + 2;

begin

	uart_inst : entity work.uart(arch)
		generic map(
			baud => 9600
		)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			uart_rx => uart_rx,
			uart_tx => uart_tx,
			tx_ena  => uart_tx_ena,
			tx_busy => uart_tx_busy,
			tx_data => uart_tx_data_i,
			rx_busy => uart_rx_busy,
			rx_err  => open,
			rx_data => uart_rx_data_i
		);
	uart_tx_data_i <= to_unsigned(character'pos(uart_tx_data), 8);
	uart_rx_data <= character'val(to_integer(uart_rx_data_i));

	edge_inst_tx : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => uart_tx_busy,
			rising  => open,
			falling => uart_tx_done
		);

	edge_inst_rx : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => uart_rx_busy,
			rising  => open,
			falling => uart_rx_done
		);

	process (clk, rst_n) begin
		if rst_n = '0' then
			tx_state <= idle;
			tx_cnt <= 0;
			rx_cnt <= 0;
		elsif rising_edge(clk) then
			case tx_state is
				when idle =>
					if tx_ena = '1' then
						tx_busy <= '1';
						uart_tx_data <= stx;
						uart_tx_ena <= '1';
						tx_cnt <= 1;
						tx_state <= execute;
					else
						tx_busy <= '0';
					end if;

				when execute =>
					if uart_tx_done = '1' then
						uart_tx_ena <= '1';
						if tx_cnt <= tx_len then
							uart_tx_data <= tx_data(tx_cnt);
							tx_cnt <= tx_cnt + 1;
						elsif tx_cnt = tx_len + 1 then
							uart_tx_data <= etx;
							tx_cnt <= tx_cnt + 1;
						elsif tx_cnt = tx_len + 2 then
							uart_tx_ena <= '0';
							tx_busy <= '0';
							tx_cnt <= 0;
							tx_state <= idle;
						end if;
					else
						uart_tx_ena <= '0';
					end if;
			end case;

			if rx_cnt = 0 and uart_rx_done = '1' and uart_rx_data = stx then
				rx_busy <= '1';
				rx_cnt <= rx_cnt + 1;
			elsif uart_rx_done = '1' then
				if uart_rx_data = etx then
					rx_busy <= '0';
					rx_len <= rx_cnt - 1;
					rx_cnt <= 0;
				else
					rx_data(rx_cnt) <= uart_rx_data;
					rx_cnt <= rx_cnt + 1;
				end if;
			end if;
		end if;
	end process;

end arch;

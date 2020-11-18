library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;

entity uart_echo_test is
	port (
		-- sys
		clk, rst_n : in std_logic;
		-- uart
		uart_rx : in std_logic; -- receive pin
		uart_tx : out std_logic -- transmit pin
	);
end uart_echo_test;

architecture arch of uart_echo_test is

	signal tx_ena, tx_busy, rx_busy, rx_err : std_logic;
	signal tx_data, rx_data : u8_t;
	signal rx_done : std_logic;

	signal buf : u8_arr_t(0 to 63);
	signal buf_cnt : integer range buf'range;

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
			tx_ena  => tx_ena,
			tx_busy => tx_busy,
			tx_data => tx_data,
			rx_busy => rx_busy,
			rx_err  => rx_err,
			rx_data => rx_data
		);

	edge_inst : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => rx_busy,
			rising  => open,
			falling => rx_done
		);

	process (clk, rst_n) begin
		if rst_n = '0' then
			tx_ena <= '0';
			buf_cnt <= 0;
		elsif rising_edge(clk) then
			if rx_done = '1' and buf_cnt < buf'high then
				buf(buf_cnt) <= rx_data;
				buf_cnt <= buf_cnt + 1;
			end if;

			if tx_busy = '0' and buf_cnt > 0 then
				tx_data <= buf(buf_cnt - 1);
				tx_ena <= '1';
				buf_cnt <= buf_cnt - 1;
			else
				tx_ena <= '0';
			end if;
		end if;
	end process;

end arch;
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

	constant txt_len_max : integer := 32;

	signal tx_ena, tx_busy, rx_busy : std_logic;
	signal tx_data, rx_data : string(1 to txt_len_max);
	signal tx_len, rx_len : integer range 1 to txt_len_max;
	signal rx_done : std_logic;

	constant price : string := "localhost";

	-- timer
	signal timer_ena : std_logic;
	signal timer_load, msec : i32_t;

begin

	uart_txt_inst : entity work.uart_txt(arch)
		generic map(
			txt_len_max => txt_len_max,
			baud        => 9600
		)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			uart_rx => uart_rx,
			uart_tx => uart_tx,
			tx_ena  => tx_ena,
			tx_busy => tx_busy,
			tx_data => tx_data,
			tx_len  => tx_len,
			rx_busy => rx_busy,
			rx_data => rx_data,
			rx_len  => rx_len
		);

	edge_inst : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => rx_busy,
			rising  => open,
			falling => rx_done
		);
	-- timer pause => msec <= load
	timer_inst : entity work.timer(arch)
		port map(
			clk   => clk,
			rst_n => rst_n,
			ena   => timer_ena,
			load  => timer_load,
			msec  => msec
		);

	process (clk, rst_n) begin
		if rst_n = '0' then
			tx_ena <= '0';
			timer_ena <= '0';
		elsif rising_edge(clk) then
			timer_ena <= '1';
			tx_data(price'range) <= price;
			tx_len <= price'length;

			if tx_busy = '0' and msec mod 1000 = 1 then
				tx_ena <= '1';
				-- == tx_data(1 to price.length);
			else
				tx_ena <= '0';
			end if;
			-- if rx_done = '1' and tx_busy = '0' then
			-- 	tx_data <= rx_data;
			-- 	tx_len <= rx_len;
			-- 	tx_ena <= '1';
			-- else
			-- 	tx_ena <= '0';
			-- end if;
		end if;
	end process;

end arch;

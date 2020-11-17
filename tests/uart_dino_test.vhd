library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;

entity uart_dino_test is
	port (
		-- sys
		clk, rst_n : in std_logic;
		-- UART
		uart_rx : in std_logic;  -- receive pin
		uart_tx : out std_logic; -- transmit pin
		-- key
		key_row : in u4r_t;
		key_col : out u4r_t
	);
end uart_dino_test;

architecture arch of uart_dino_test is

	signal tx_ena, tx_busy : std_logic;
	signal tx_data : u8_t;
	signal pressed, key_on_press : std_logic;
	signal key : i4_t;

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
			rx_busy => open,
			rx_err  => open,
			rx_data => open
		);

	key_inst : entity work.key(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			key_row => key_row,
			key_col => key_col,
			pressed => pressed,
			key     => key
		);

	edge_inst : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => pressed,
			rising  => key_on_press,
			falling => open
		);

	process (clk, rst_n) begin
		if rst_n = '0' then

		elsif rising_edge(clk) then
			if key_on_press = '1' then
				tx_data <= to_unsigned(key, 8);
				tx_ena <= '1';
			else
				tx_ena <= '0';
			end if;
		end if;
	end process;

end arch;

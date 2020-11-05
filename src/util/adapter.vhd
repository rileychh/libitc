-- entities that change signal names and more to comply with other sources' coding style

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fifo is
	generic (
		addr_width : integer := 8;
		data_width : integer := 8
	);
	port (
		-- system
		clk, rst_n : in std_logic;
		-- user logic: flags
		rd_ena, wr_ena : in std_logic;
		data_cnt       : out integer range 0 to 2 ** addr_width - 1;
		-- user logic: data
		data_in  : in std_logic_vector(data_width - 1 downto 0);
		data_out : out std_logic_vector(data_width - 1 downto 0)
	);
end fifo;

architecture arch of fifo is

	signal data_cnt_i : std_logic_vector(addr_width downto 0);

begin

	data_cnt <= to_integer(unsigned(data_cnt_i));

	fifo_inst : entity work.fifo_eewiki(arch)
		generic map(
			ADDR_W  => addr_width,
			DATA_W  => data_width,
			BUFF_L  => 2 ** addr_width - 1,
			ALMST_F => 1,
			ALMST_E => 1
		)
		port map(
			clk         => clk,
			n_reset     => rst_n,
			rd_en       => rd_ena,
			wr_en       => wr_ena,
			data_in     => data_in,
			data_out    => data_out,
			data_count  => data_cnt_i,
			empty       => open,
			full        => open,
			almst_empty => open,
			almst_full  => open,
			err         => open
		);

end arch;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;

entity i2c is
	generic (
		bus_freq : integer := 100_000
	);
	port (
		-- system
		clk, rst_n : in std_logic;
		-- I2C slave
		scl, sda : inout std_logic;
		-- user logic: flags
		data_in_wr_ena, data_out_rd_ena : in std_logic;
		data_in_cnt, data_out_cnt       : out integer range 0 to 2 ** 8 - 1;
		-- user logic: data
		data_in  : in std_logic_vector(15 downto 0); -- address & read/write & data
		data_out : out std_logic_vector(7 downto 0)
	);
end i2c;

architecture arch of i2c is

	signal i2c_data_in : std_logic_vector(15 downto 0);
	signal i2c_data_out : std_logic_vector(7 downto 0);
	signal data_in_rd_ena, data_out_wr_ena : std_logic;

	signal ena, busy, err : std_logic;
	signal busy_prev, busy_rise, busy_fall : std_logic;

	signal rw_prev : std_logic;

begin

	fifo_inst_in : entity work.fifo(arch)
		generic map(
			addr_width => 8,
			data_width => 16
		)
		port map(
			clk      => clk,
			rst_n    => rst_n,
			rd_ena   => data_in_rd_ena,
			wr_ena   => data_in_wr_ena,
			data_cnt => data_in_cnt,
			data_in  => data_in,
			data_out => i2c_data_in
		);

	fifo_inst_data_out : entity work.fifo(arch)
		generic map(
			addr_width => 8,
			data_width => 8
		)
		port map(
			clk      => clk,
			rst_n    => rst_n,
			rd_ena   => data_out_rd_ena,
			wr_ena   => data_out_wr_ena,
			data_cnt => data_out_cnt,
			data_in  => i2c_data_out,
			data_out => data_out
		);

	i2c_master_inst : entity work.i2c_master(logic)
		generic map(
			input_clk => sys_clk_freq,
			bus_clk   => bus_freq
		)
		port map(
			clk       => clk,
			reset_n   => rst_n,
			ena       => ena,
			addr      => i2c_data_in(15 downto 9),
			rw        => i2c_data_in(8),
			data_wr   => i2c_data_in(7 downto 0),
			busy      => busy,
			data_rd   => i2c_data_out,
			ack_error => err,
			sda       => sda,
			scl       => scl
		);

	ena <= '1' when data_in_cnt > 0 else '0';

	busy_rise <= not busy_prev and busy;
	busy_fall <= busy_prev and not busy;

	process (clk, rst_n) begin
		if rst_n = '0' then
			data_in_rd_ena <= '0'; -- enables are normally low
			data_out_wr_ena <= '0';
			busy_prev <= '1';
			rw_prev <= '0';
		elsif rising_edge(clk) then
			-- default values
			data_in_rd_ena <= '0'; -- enables are normally low
			data_out_wr_ena <= '0';
			busy_prev <= busy;

			if busy_rise = '1' and err = '0' and data_in_cnt > 0 then -- transaction latched, get new data unless errored
				rw_prev <= data_in(8);
				data_in_rd_ena <= '1'; -- pulse enable high, next data set
			end if;

			if busy_fall = '1' and rw_prev = '1' and data_out_cnt < data_out_cnt'high then -- previous transaction is done
					data_out_wr_ena <= '1'; -- store the read data
			end if;
		end if;
	end process;

end arch;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;

-- this SPI interface is in simplex (send only) mode
entity spi is
	generic (
		cpol     : std_logic := '0';
		cpha     : std_logic := '0';
		bus_freq : integer   := 15_000_000 -- max freq. is sys_clk_freq / 2
	);

	port (
		-- system
		clk, rst_n : in std_logic;
		-- SPI slave
		sclk, mosi, ss : out std_logic;
		-- user logic: flags
		data_in_wr_ena : in std_logic;
		data_in_cnt    : out integer range 0 to 2 ** 8 - 1;
		-- user logic: data
		data_in : in std_logic_vector(7 downto 0)
	);
end spi;

architecture arch of spi is

	signal ss_i : std_logic_vector(0 to 0);

	signal spi_data_in : std_logic_vector(7 downto 0);
	signal data_in_rd_ena : std_logic;
	signal ena, busy : std_logic;
	signal busy_prev, busy_rise : std_logic;

begin

	fifo_inst_data_in : entity work.fifo(arch)
		generic map(
			addr_width => 8,
			data_width => 8
		)
		port map(
			clk      => clk,
			rst_n    => rst_n,
			rd_ena   => data_in_rd_ena,
			wr_ena   => data_in_wr_ena,
			data_cnt => data_in_cnt,
			data_in  => data_in,
			data_out => spi_data_in
		);

	spi_master_inst : entity work.spi_master(logic)
		generic map(
			slaves  => 1,
			d_width => 8
		)
		port map(
			clock   => clk,
			reset_n => rst_n,
			enable  => ena,
			cpol    => cpol,
			cpha    => cpha,
			cont    => ena,
			clk_div => sys_clk_freq / bus_freq / 2,
			addr    => 0,
			tx_data => spi_data_in,
			miso    => 'X', -- open
			sclk    => sclk,
			ss_n    => ss_i,
			mosi    => mosi,
			busy    => busy,
			rx_data => open
		);

	ena <= '1' when data_in_cnt > 0 else '0';
	ss <= ss_i(0);

	busy_rise <= not busy_prev and busy;

	process (clk, rst_n) begin
		if rst_n = '0' then
			data_in_rd_ena <= '0'; -- enables are normally low
			busy_prev <= '1';
		elsif rising_edge(clk) then
			data_in_rd_ena <= '0'; -- enables are normally low
			busy_prev <= busy;

			if busy_rise = '1' then -- transaction latched, get new data
				data_in_rd_ena <= '1'; -- pulse enable high, next data set
			end if;
		end if;
	end process;

end arch;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;

-- default is 9600 8N1 (8-bit data, no parity, 1 stop bit)
entity uart is
	generic (
		baud : integer := 9600
	);
	port (
		-- system
		clk, rst_n : in std_logic;
		-- UART bus
		rx : in std_logic;
		tx : out std_logic;
		-- user logic: flags
		data_in_wr_ena, data_out_rd_ena : in std_logic;
		data_in_cnt, data_out_cnt       : out integer range 0 to 2 ** 8 - 1;
		-- user logic: data
		data_in  : in std_logic_vector(7 downto 0);
		data_out : out std_logic_vector(7 downto 0)
	);
end uart;

architecture arch of uart is

	signal uart_data_in, uart_data_out : std_logic_vector(7 downto 0);
	signal data_in_rd_ena, data_out_wr_ena : std_logic;

	signal ena, rx_busy, tx_busy : std_logic;
	signal tx_busy_prev, tx_busy_rise : std_logic;
	signal rx_busy_prev, rx_busy_fall : std_logic;

begin

	fifo_inst_in : entity work.fifo(arch)
		generic map(
			addr_width => 8,
			data_width => 16
		)
		port map(
			clk      => clk,
			rst_n    => rst_n,
			rd_ena   => data_in_rd_ena,
			wr_ena   => data_in_wr_ena,
			data_cnt => data_in_cnt,
			data_in  => data_in,
			data_out => uart_data_in
		);

	fifo_inst_data_out : entity work.fifo(arch)
		generic map(
			addr_width => 8,
			data_width => 8
		)
		port map(
			clk      => clk,
			rst_n    => rst_n,
			rd_ena   => data_out_rd_ena,
			wr_ena   => data_out_wr_ena,
			data_cnt => data_out_cnt,
			data_in  => uart_data_out,
			data_out => data_out
		);

	uart_eewiki_inst : entity work.uart_eewiki(logic)
		generic map(
			clk_freq  => sys_clk_freq,
			baud_rate => baud,
			os_rate   => 16,
			d_width   => 8,
			parity    => 0,
			parity_eo => '-' -- open
		)
		port map(
			clk      => clk,
			reset_n  => rst_n,
			tx_ena   => ena,
			tx_data  => uart_data_in,
			rx       => rx,
			rx_busy  => rx_busy,
			rx_error => open,
			rx_data  => uart_data_out,
			tx_busy  => tx_busy,
			tx       => tx
		);

	ena <= '1' when data_in_cnt > 0 else '0';

	tx_busy_rise <= not tx_busy_prev and tx_busy;
	rx_busy_fall <= rx_busy_prev and not rx_busy;

	process (clk, rst_n) begin
		if rst_n = '0' then
			data_in_rd_ena <= '0'; -- enables are normally low
			data_out_wr_ena <= '0';
		elsif rising_edge(clk) then
			data_in_rd_ena <= '0'; -- enables are normally low
			data_out_wr_ena <= '0';
			rx_busy_prev <= rx_busy;
			tx_busy_prev <= tx_busy;

			if tx_busy_rise = '1' then -- transaction latched, get new data
				data_in_rd_ena <= '1'; -- pulse enable high, next data set
			end if;

			if rx_busy_fall = '1' then -- previous transaction is done
				data_out_wr_ena <= '1'; -- store the read data
			end if;
		end if;
	end process;

end arch;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;

entity debounce is
	generic (
		stable_time : integer := 10 -- time button must remain stable in ms
	);
	port (
		-- system
		clk, rst_n : in std_logic;
		-- user logic
		sig_in  : in std_logic;
		sig_out : out std_logic
	);
end debounce;

architecture arch of debounce is

begin

	debounce_eewiki_inst : entity work.debounce_eewiki(logic)
		generic map(
			clk_freq    => sys_clk_freq,
			stable_time => stable_time
		)
		port map(
			clk     => clk,
			reset_n => rst_n,
			button  => sig_in,
			result  => sig_out
		);

end arch;

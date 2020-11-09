library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;

entity spi is
	generic (
		cpol     : std_logic := '0';       -- spi clock polarity
		cpha     : std_logic := '0';       -- spi clock phase
		bus_freq : integer   := 15_000_000 -- max freq. is sys_clk_freq / 2
	);

	port (
		-- system
		clk, rst_n : in std_logic;
		-- SPI slave
		mosi : out std_logic; -- master out, slave in
		sclk : out std_logic; -- spi clock
		ss_n : out std_logic; -- slave select
		-- user logic
		ena     : in std_logic;  -- initiate transaction
		busy    : out std_logic; -- busy / data ready signal
		data_in : in byte_t      -- data to transmit
	);
end spi;

architecture arch of spi is

	constant clk_ratio : integer := sys_clk_freq / bus_freq; -- current clk_div
	constant last_bit_rx : integer := 15 + to_integer(cpha); -- last rx data bit location

	type state_t is (idle, execute); -- state machine data type
	signal state : state_t; -- current state

	signal count : integer range 0 to clk_ratio; -- counter to trigger sclk from system clock
	signal clk_toggles : integer range 0 to 17; -- count spi clock toggles
	signal assert_data : std_logic; -- '1' is data_in sclk toggle, '0' is rx sclk toggle
	signal data_in_i : byte_t; -- transmit data buffer

begin

	process (clk, rst_n) begin
		if rst_n = '0' then -- reset system
			busy <= '1'; -- set busy signal
			ss_n <= '1'; -- deassert all slave select lines
			mosi <= 'Z'; -- set master out to high impedance
			state <= idle; -- go to ready state when reset is exited 
		elsif rising_edge(clk) then
			case state is -- state machine 
				when idle =>
					busy <= '0'; -- clock out not busy signal
					ss_n <= '1'; -- set all slave select outputs high
					mosi <= 'Z'; -- set mosi output high impedance

					-- user input to initiate transaction
					if ena = '1' then
						count <= clk_ratio - 1; -- initiate system-to-spi clock counter
						clk_toggles <= 0; -- initiate clock toggle counter
						sclk <= cpol; -- set spi clock polarity
						assert_data <= not cpha; -- set spi clock phase
						data_in_i <= data_in; -- latch in data for transmit into buffer
						state <= execute; -- proceed to execute state
					end if;

				when execute =>
					busy <= '1'; -- set busy signal
					ss_n <= '0'; -- set slave select output

					-- system clock to sclk ratio is met
					if count = clk_ratio - 1 then
						assert_data <= not assert_data; -- switch transmit/receive indicator

						-- transmit spi clock toggle
						if assert_data = '1' and clk_toggles < last_bit_rx then
							mosi <= data_in_i(7); -- clock out data bit
							data_in_i <= data_in_i sll 1; -- shift data transmit buffer
						end if;

						-- last data receive, but continue
						if clk_toggles = last_bit_rx and ena = '1' then
							data_in_i <= data_in; -- reload transmit buffer
							clk_toggles <= last_bit_rx - 17; -- reset spi clock toggle counter
							busy <= '0'; -- clock out signal that data is latched
						end if;

						-- end of transaction
						if clk_toggles = 17 and ena = '0' then
							state <= idle; -- return to idle state
						end if;

						-- spi clock toggle needed
						if clk_toggles < 17 then
							sclk <= not sclk; -- toggle spi clock
						end if;

						if clk_toggles = 17 then
							clk_toggles <= 0; -- reset spi clock toggles counter
						else
							clk_toggles <= clk_toggles + 1; -- increment spi clock toggles counter
						end if;

						count <= 0; -- reset system-to-spi clock counter
					else -- system clock to sclk ratio not met
						count <= count + 1; -- increment counter
					end if;
			end case;
		end if;
	end process;
end arch;

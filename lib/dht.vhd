library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;

entity dht is
	port (
		-- system
		clk   : in std_logic;
		rst_n : in std_logic;
		-- dht
		dht_data : inout std_logic;
		-- user logic
		temp_int, hum_int : out integer range 0 to 99;
		temp_dec, hum_dec : out integer range 0 to 9
	);
end dht;

architecture arch of dht is

	-- rising and falling edge detector
	signal dht_rise : std_logic; -- dht_data changes from low to high
	signal dht_fall : std_logic; -- dht_data changes from high to low

	-- timer
	signal clk_1m : std_logic; -- clock for timing
	signal timer_clr : std_logic; -- if high, timer resets
	signal timer_us : integer range 0 to 1_000_000; -- microsecond count

	-- data received
	signal rx : unsigned(39 downto 0);
	signal bit_cnt : integer range 0 to 39;

	type dht_state_t is (delay, start_low, start_high, ack_low, ack_high, read_data_low, read_data_high);
	signal state : dht_state_t;

begin

	clk_inst : entity work.clk(arch)
		generic map(
			freq => 1_000_000
		)
		port map(
			clk_in  => clk,
			rst_n   => rst_n,
			clk_out => clk_1m
		);

	-- edge detector
	edge_inst : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => dht_data,
			rising  => dht_rise,
			falling => dht_fall
		);

	-- timer
	process (clk_1m, rst_n, timer_clr) begin
		if rst_n = '0' or timer_clr = '1' then
			timer_us <= 0;
		elsif rising_edge(clk_1m) then
			timer_us <= timer_us + 1;
		end if;
	end process;

	-- state machine
	process (clk, rst_n) begin
		if rst_n = '0' then
			dht_data <= 'Z'; -- release wire
			timer_clr <= '0';
			state <= state'left; -- reset state
			temp_int <= 0; -- clear outputs
			temp_dec <= 0;
			hum_int <= 0;
			hum_dec <= 0;
		elsif rising_edge(clk) then
			case state is
				when delay => -- wait for 1s
					if timer_us <= 1_000_000 then
						dht_data <= 'Z';
						timer_clr <= '0';
					else
						timer_clr <= '1';
						state <= start_low;
					end if;

				when start_low => -- pull down at least 18ms
					if timer_us <= 20_000 then
						dht_data <= '0';
						timer_clr <= '0';
					else
						dht_data <= 'Z';
						timer_clr <= '1';
						state <= start_high;
					end if;

				when start_high => -- release 20 to 40us
					if timer_us <= 40 then
						timer_clr <= '0';
						if dht_fall = '1' then
							timer_clr <= '1';
							state <= ack_low;
						end if;
					else -- error: timeout
						timer_clr <= '1';
						state <= delay;
					end if;

				when ack_low => -- dht pulls down for 80us
					if dht_rise = '1' then
						state <= ack_high;
					end if;

				when ack_high => -- dht pulls up for 80us
					if dht_fall = '1' then
						bit_cnt <= 39; -- reset bit counter
						rx <= (others => '0'); -- reset received data
						state <= read_data_low;
					end if;

				when read_data_low => -- dht pulls down for 50us
					if dht_rise = '1' then
						timer_clr <= '1';
						state <= read_data_high;
					end if;

				when read_data_high => -- dht pulls up 26~28us => '0', 70us => '1' 
					if dht_fall = '1' then
						timer_clr <= '1';
						if timer_us <= 50 then -- dht pulls up more than 28us, less then 70us
							rx(bit_cnt) <= '0';
						else
							rx(bit_cnt) <= '1';
						end if;

						if bit_cnt = 0 then -- all 40 bits of data is transferred
							hum_int <= to_integer(rx(39 downto 32));
							hum_dec <= to_integer(rx(31 downto 24));
							temp_int <= to_integer(rx(23 downto 16));
							temp_dec <= to_integer(rx(15 downto 8));
							state <= delay;
						else
							bit_cnt <= bit_cnt - 1;
							state <= read_data_low;
						end if;
					else -- while waiting for falling edge, count time passed
						timer_clr <= '0';
					end if;
			end case;
		end if;
	end process;

end arch;

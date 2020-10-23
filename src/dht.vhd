library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package dht_p is
	component dht
		port (
			-- dht
			dht_data : inout std_logic;
			-- system
			clk : in std_logic;
			rst : in std_logic;
			-- user logic
			temp : out integer range 0 to 50;
			hum  : out integer range 0 to 80
		);
	end component;
end package;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dht is
	port (
		-- dht
		dht_data : inout std_logic;
		-- system
		clk : in std_logic;
		rst : in std_logic;
		-- user logic
		temp : out integer range 0 to 50;
		hum  : out integer range 0 to 80
	);
end dht;

architecture arch of dht is

	-- rising and falling edge detector
	signal dht_data_prev_1 : std_logic; -- state of dht_data 1 clock ago
	signal dht_data_prev_2 : std_logic; -- state of dht_data 2 clocks ago
	signal dht_rising : std_logic; -- dht_data changes from low to high
	signal dht_falling : std_logic; -- dht_data changes from high to low

	-- timer
	signal clk_1m : std_logic; -- clock for timing
	signal timer_clr : std_logic; -- if high, timer resets
	signal timer_us : integer range 0 to 2 ** 20 - 1; -- microsecond count

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
			rst     => rst,
			clk_out => clk_1m
		);

	-- timer
	process (clk_1m, rst, timer_clr) begin
		if rst = '0' or timer_clr = '1' then
			timer_us <= 0;
		elsif rising_edge(clk_1m) then
			timer_us <= timer_us + 1;
		end if;
	end process;

	-- edge detector
	process (clk, rst) begin
		if rst = '0' then
			dht_data_prev_1 <= '1';
			dht_data_prev_2 <= '1';
		elsif rising_edge(clk) then
			dht_data_prev_1 <= dht_data;
			dht_data_prev_2 <= dht_data_prev_1;
		end if;
	end process;
	dht_rising <= not dht_data_prev_2 and dht_data_prev_1;
	dht_falling <= dht_data_prev_2 and not dht_data_prev_1;

	-- state machine
	process (clk, rst) begin
		if rst = '0' then
			dht_data <= 'Z'; -- release wire
			timer_clr <= '0';
			state <= state'left; -- reset state
			temp <= 0; -- clear temperature output
			hum <= 0; -- clear humidity output
		elsif rising_edge(clk) then
			case state is
				when delay => -- wait for 1s
					if timer_us < 1_000_000 then
						dht_data <= 'Z';
						timer_clr <= '0';
					else
						timer_clr <= '1';
						state <= start_low;
					end if;

				when start_low => -- pull down at least 18ms
					if timer_us < 20_000 then
						dht_data <= '0';
						timer_clr <= '0';
					else
						dht_data <= 'Z';
						timer_clr <= '1';
						state <= start_high;
					end if;

				when start_high => -- release 20 to 40us
					if timer_us < 40 then
						timer_clr <= '0';
						if dht_falling = '1' then
							timer_clr <= '1';
							state <= ack_low;
						end if;
					else -- error: timeout
						timer_clr <= '1';
						state <= delay;
					end if;

				when ack_low => -- dht pulls down for 80us
					if dht_rising = '1' then
						state <= ack_high;
					end if;

				when ack_high => -- dht pulls up for 80us
					if dht_falling = '1' then
						bit_cnt <= 39; -- reset bit counter
						rx <= (others => '0'); -- reset received data
						state <= read_data_low;
					end if;

				when read_data_low => -- dht pulls down for 50us
					if dht_rising = '1' then
						timer_clr <= '1';
						state <= read_data_high;
					end if;

				when read_data_high => -- dht pulls up 26~28us => '0', 70us => '1' 
					if dht_falling = '1' then
						timer_clr <= '1';
						if timer_us < 50 then -- dht pulls up more than 28us, less then 70us
							rx(bit_cnt) <= '0';
						else
							rx(bit_cnt) <= '1';
						end if;

						if bit_cnt = 0 then -- all 40 bits of data is transferred
							temp <= to_integer(rx(23 downto 16));
							hum <= to_integer(rx(39 downto 32));
							-- TODO checksum
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
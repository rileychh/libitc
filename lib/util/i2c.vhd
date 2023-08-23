library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;

entity i2c is
	generic (
		bus_freq : integer := 400_000
	);

	port (
		-- system
		clk, rst_n : in std_logic;
		-- I2C slave
		scl, sda : inout std_logic;
		-- user logic
		ena      : in std_logic;  -- if high, start the transmission
		busy     : out std_logic; -- if high, addr, rw and tx will be ignored
		cmd      : in u8_t;       -- slave address & r/w (high read, low write)
		data_in  : in u8_t;       -- byte to write to slave
		data_out : out u8_t       -- byte read from slave
	);
end i2c;

architecture arch of i2c is

	signal scl_clk : std_logic; -- clock of SCL
	signal sda_clk : std_logic; -- write to SDA on rising edge, read from SDA on falling edge

	signal scl_low : std_logic; -- sda_clk changes from low to high (middle of SCL low)
	signal scl_high : std_logic; -- sda_clk changes from high to low (middle of SCL high)

begin

	timing_b : block -- timing generator
		constant divider : integer := (sys_clk_freq / bus_freq) / 4; -- number of clocks in 1/4 cycle of scl
		signal stretch : std_logic; -- wait for slave to release SCL
		signal timer : integer range 0 to divider * 4 - 1; -- timing for clock generation
	begin
		process (clk, rst_n) begin
			if rst_n = '0' then
				stretch <= '0';
				timer <= 0;
			elsif rising_edge(clk) then
				if timer = timer'high then -- end of timing cycle
					timer <= 0; -- reset timer
				elsif stretch = '0' then -- clock stretching from slave not detected
					timer <= timer + 1; -- continue clock generation timing
				end if;

				case timer is
					when 0 to divider - 1 => -- first 1/4 cycle of clocking
						scl_clk <= '0';
						sda_clk <= '0';

					when divider to divider * 2 - 1 => -- second 1/4 cycle of clocking
						scl_clk <= '0';
						sda_clk <= '1';

					when divider * 2 to divider * 3 - 1 => -- third 1/4 cycle of clocking
						scl_clk <= '1'; -- release scl
						if scl = '0' then -- detect if slave is stretching clock
							stretch <= '1';
						else
							stretch <= '0';
						end if;
						sda_clk <= '1';

					when others => -- last 1/4 cycle of clocking
						scl_clk <= '1';
						sda_clk <= '0';
				end case;
			end if;
		end process;
	end block;

	edge_inst : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => sda_clk,
			rising  => scl_low,
			falling => scl_high
		);

	main_b : block
		--                   0     1      2          3        4          5           6         7          8
		type i2c_state_t is (idle, start, cmd_write, ack_cmd, data_read, data_write, ack_read, ack_write, stop);
		signal state : i2c_state_t;

		signal scl_ena : std_logic; -- SCL enable
		signal sda_out : std_logic; -- internal SDA (tri-state open drain buffer)
		signal cnt : integer range 8 downto 0; -- generic loop counter
		signal command : u8_t; -- command byte (address + r/w)
		signal err : std_logic; -- error flag, automatically retry
	begin
		process (clk, rst_n) begin
			if rst_n = '0' then
				scl_ena <= '0';
				sda_out <= '1';
				state <= idle; -- return to initial state
				cnt <= cnt'high; -- reset counter
				err <= '0';
				busy <= '1'; -- indicate not available
				data_out <= (others => '0'); -- clear data output
			elsif rising_edge(clk) then
				case state is
					when idle =>
						if ena = '1' then -- start
							command <= cmd;
							busy <= '1';
							state <= start;
						elsif err = '1' then
							err <= '0';
							state <= start;
						else -- done
							busy <= '0';
						end if;

					when start => -- write low to SDA while SCL is high
						if scl_high = '1' then
							scl_ena <= '1';
							sda_out <= '0';
							state <= cmd_write;
						end if;

					when cmd_write =>
						if scl_low = '1' then
							if cnt = 0 then
								sda_out <= '1';
								state <= ack_cmd;
								cnt <= cnt'high;
							else
								sda_out <= command(cnt - 1);
								cnt <= cnt - 1;
							end if;
						end if;

					when ack_cmd =>
						if scl_high = '1' then
							if sda = '0' then -- ACK
								if command(0) = '1' then -- read
									state <= data_read;
								else -- write
									state <= data_write;
								end if;
							else -- NACK
								err <= '1';
								state <= stop;
							end if;
						end if;

					when data_read => -- TODO refactor this and ack_read
						if scl_low = '1' then -- first
							sda_out <= '1'; -- make sure sda is released during read
							if cnt /= 0 then
								cnt <= cnt - 1;
							end if;
						end if;

						if scl_high = '1' then -- second
							data_out(cnt) <= sda;
							if cnt = 0 then
								state <= ack_read; -- write acknowledgement immediately
								if ena = '1' then -- continuous mode
									busy <= '0'; -- ready for new data
								end if;
								cnt <= cnt'high;
							end if;
						end if;

					when data_write =>
						if scl_low = '1' then
							if cnt = 0 then
								sda_out <= '1'; -- release SDA for acknowledgement
								state <= ack_write;
								cnt <= cnt'high;
								if ena = '1' then -- continuous mode
									busy <= '0'; -- ready for new data
								end if;
							else
								sda_out <= data_in(cnt - 1);
								cnt <= cnt - 1;
							end if;
						end if;

					when ack_read => -- send ACK to slave
						if scl_low = '1' then -- first
							if ena = '1' then -- continuous mode
								sda_out <= '0'; -- send ACK
							else -- last byte
								sda_out <= '1'; -- send NACK to stop
							end if;
						end if;

						if scl_high = '1' then -- second
							if ena = '1' then -- continuous mode
								if command = cmd then -- command not changed
									state <= data_read;
								else -- command changed
									command <= cmd; -- update command
									state <= start; -- repeated start
								end if;
								busy <= '1'; -- data is latched
							else
								state <= stop;
							end if;
						end if;

					when ack_write => -- read ACK from slave
						if scl_high = '1' then
							if sda = '0' then -- ACK
								if ena = '1' then -- continuous mode
									if command = cmd then -- command not changed
										state <= data_write;
									else -- command changed
										command <= cmd; -- update command
										state <= start; -- repeated start
									end if;
									busy <= '1'; -- data is latched
								else
									state <= stop;
								end if;
							else -- NACK
								err <= '1';
								state <= stop;
							end if;
						end if;

					when stop => -- write high to SDA while SCL is high
						if scl_low = '1' and sda = '1' then
							sda_out <= '0';
						end if;

						if scl_high = '1' then
							scl_ena <= '0';
							sda_out <= '1';
							state <= idle;
						end if;
				end case;
			end if;
		end process;

		scl <= '0' when scl_clk = '0' and scl_ena = '1' else 'Z';
		sda <= '0' when sda_out = '0' else 'Z';
	end block;

end arch;

-- I2C master generic interface
--
-- reference:
-- https://www.digikey.com/eewiki/pages/viewpage.action?pageId=10125324
-- https://www.youtube.com/watch?v=skkyudHHSWY
--
-- usage:
-- 1. to write a byte: 
--    addr = slave address
--    rw = '0'
--    tx = byte to write
--    ena = high pulse
--    wait for falling edge of busy
--
-- 2. to read a byte: 
--    addr = slave address
--    rw = '1'
--    ena = high pulse
--    wait for falling edge of busy
--    byte read = rx
--
-- 3. to write to a register: 
--    addr = slave address
--    rw = '0'
--    tx = register address
--    ena = '1'
--    wait for falling edge of busy
--    tx = 1st byte to write
--    wait for falling edge of busy
--    tx = 2nd byte to write
--    ...
--    ena = '0'
--
-- 4. to read a register: 
--    addr = slave address
--    rw = '0'
--    tx = register address
--    ena = '1'
--    wait for falling edge of busy
--    rw = '1'
--    1st byte read = rx
--    wait for falling edge of busy
--    2nd byte read = rx
--    ...
--    ena = '0'
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package i2c_p is
	constant read : std_logic := '1';
	constant write : std_logic := '0';
	constant ack : std_logic := '0';
	constant nack : std_logic := '1';

	component i2c
		port (
			-- I2C slave
			scl, sda : inout std_logic;
			-- internal
			clk  : in std_logic;             -- 800kHz or 200kHz
			rst  : in std_logic;             -- low active
			ena  : in std_logic;             -- if high, latch in new input
			busy : out std_logic;            -- if high, addr, rw and tx will be ignored
			addr : in unsigned(6 downto 0);  -- slave address
			rw   : in std_logic;             -- high read, low write
			rx   : out unsigned(7 downto 0); -- byte read from slave
			tx   : in unsigned(7 downto 0);  -- byte to write to slave
			-- debug
			dbg_state : out unsigned(3 downto 0)
		);
	end component;
end package;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.i2c_p.all;

entity i2c is
	port (
		-- I2C slave
		scl, sda : inout std_logic;
		-- internal
		clk  : in std_logic;             -- 800kHz or 200kHz
		rst  : in std_logic;             -- low active
		ena  : in std_logic;             -- if high, latch in new input
		busy : out std_logic;            -- if high, addr, rw and tx will be ignored
		addr : in unsigned(6 downto 0);  -- slave address
		rw   : in std_logic;             -- high read, low write
		rx   : out unsigned(7 downto 0); -- byte read from slave
		tx   : in unsigned(7 downto 0);  -- byte to write to slave
		-- debug
		dbg_state : out unsigned(3 downto 0)
	);
end i2c;

architecture arch of i2c is

	-- I2C state machine
	-- | state | read/write | what                                    |
	-- | ----- | ---------- | --------------------------------------- |
	-- | idle  | -          | do nothing                              |
	-- | start | w          | send start condition                    |
	-- | cmd   | w          | send 6-bit address + 1-bit read / write |
	-- | ack1  | r          | receive slave acknowledgment bit        |
	-- | data  | r/w        | receive/send data byte                  |
	-- | ack2  | w/r        | send/receive acknowledgment bit         |
	-- | stop  | w          | send stop condition                     |
	type state_t is (idle, start, cmd, ack1, data, ack2, stop);
	signal state : state_t;

	-- converts final output from '0' and '1' to '0' and 'Z';
	-- write at wire, read directly at port
	signal scl_wire, sda_wire : std_logic;

	-- indicates SCL is being stretched (held low) by slave, wait for slave to release
	signal stretch : std_logic;

	-- saves input when not busy
	signal cmd_reg : unsigned(7 downto 0); -- command = addr + rw
	signal tx_reg : unsigned(7 downto 0);

	-- latches in new input value
	procedure update is begin
		cmd_reg <= addr & rw;
		tx_reg <= tx;
	end procedure;

	-- releases SCL when resetting, idling, starting or stopping
	signal scl_ena : std_logic;

	-- bit count: loop inside state for a byte
	signal bit_cnt : integer range 0 to 7;

begin

	dbg_state <= to_unsigned(state_t'pos(state), 4);

	-- SCL control
	process (clk, rst) begin
		if rst = '0' then
			scl_wire <= '1';
			stretch <= '0';
		elsif rising_edge(clk) then
			case state is
				when idle | start | stop =>
					scl_wire <= '1';
				when others =>
					-- TODO test this
					if scl_wire = '1' and scl = '0' then -- master can't pull SCL high
						stretch <= '1'; -- slave is stretching clock
					else -- pause when stretching
						scl_wire <= not scl_wire; -- SCL is half the frequency of clk
					end if;
			end case;
		end if;
	end process;

	-- SDA control, state machine
	-- write when SCL is '0', read or send start/stop when SCL is '1'
	-- busy flag, state machine and bit counter are all changed when SCL is '1'
	process (clk, rst) begin
		if rst = '0' then
			sda_wire <= '1';
			busy <= '1';
			state <= idle;
			bit_cnt <= 7;
		elsif falling_edge(clk) and stretch = '0' then -- update SDA half a clock after SCL, pause when stretching
			case state is
				when idle =>
					sda_wire <= '1'; -- release SDA
					busy <= '0';
					if ena = '1' then
						update;
						busy <= '1';
						state <= start;
					end if;

				when start =>
					sda_wire <= '0'; -- SCL = '1' and falling_edge(SDA) == start
					state <= cmd;
					bit_cnt <= 7; -- prepare bit_cnt for command state

				when cmd =>
					if scl_wire = '0' then
						sda_wire <= cmd_reg(bit_cnt); -- send current bit
					elsif scl_wire = '1' then
						if bit_cnt = 0 then
							bit_cnt <= 7; -- reset bit counter
							state <= ack1;
						else
							bit_cnt <= bit_cnt - 1;
						end if;
					end if;

				when ack1 =>
					if scl_wire = '0' then
						sda_wire <= '1'; -- release SDA for acknowledgment
					elsif scl_wire = '1' then
						if sda = ack then
							state <= data;
						elsif sda = nack then
							state <= stop;
						end if;
					end if;

				when data =>
					if scl_wire = '0' then
						if cmd_reg(0) = write then
							sda_wire <= tx_reg(bit_cnt);
						end if;
					elsif scl_wire = '1' then
						if cmd_reg(0) = read then
							rx(bit_cnt) <= sda;
						end if;

						if bit_cnt = 0 then
							bit_cnt <= 7; -- reset bit counter
							state <= ack2;
							if ena = '1' then -- continuous mode (block r/w)
								busy <= '0'; -- ready to accept new data
							end if;
						else
							bit_cnt <= bit_cnt - 1;
						end if;
					end if;

				when ack2 =>
					if scl_wire = '0' then
						if cmd_reg(0) = write then -- r/w bit is write
							sda_wire <= '1'; -- release SDA for acknowledgment
						elsif cmd_reg(0) = read then -- r/w bit is read
							sda_wire <= '0'; -- send acknowledgment bit
						end if;
					elsif scl_wire = '1' then
						if (cmd_reg(0) = write and sda = nack) or ena = '0' then -- receivied NACK or transmission complete
							state <= stop;
						elsif ena = '1' then -- continuous mode (block r/w)
							if cmd_reg = addr & rw then -- command has not changed
								state <= data; -- keep sending/receiving bytes
							else
								state <= start; -- send a restart
							end if;
							update;
							busy <= '1';
						end if;
					end if;

				when stop =>
					sda_wire <= '1'; -- SCL = '1' and rising_edge(SDA) == stop
					state <= idle;
			end case;
		end if;
	end process;

	-- convert internal wire to open drain
	scl <= 'Z' when scl_wire = '1' else '0';
	sda <= 'Z' when sda_wire = '1' else '0';

end arch;
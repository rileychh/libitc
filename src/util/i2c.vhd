-- I2C (IIC) master interface

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package i2c_p is
	constant read : std_logic := '1';
	constant write : std_logic := '0';

	component i2c
		port (
			-- I2C slave
			scl : out std_logic;
			sda : inout std_logic;
			-- internal
			clk  : in std_logic;             -- 800kHz
			rst  : in std_logic;             -- low active
			ena  : in std_logic;             -- if high, latch in new input
			busy : out std_logic;            -- if high, addr, rw and tx will be ignored
			addr : in unsigned(6 downto 0);  -- slave address
			rw   : in std_logic;             -- high read, low write
			rx   : out unsigned(7 downto 0); -- byte read from slave
			tx   : in unsigned(7 downto 0)   -- byte to write to slave
		);
	end component;
end package;

--
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

use work.i2c_p.all;

entity i2c is
	port (
		-- I2C slave
		scl : out std_logic;
		sda : inout std_logic;
		-- internal
		clk  : in std_logic;             -- 800kHz
		rst  : in std_logic;             -- low active
		ena  : in std_logic;             -- if high, latch in new input
		busy : out std_logic;            -- if high, addr, rw and tx will be ignored
		addr : in unsigned(6 downto 0);  -- slave address
		rw   : in std_logic;             -- high read, low write
		rx   : out unsigned(7 downto 0); -- byte read from slave
		tx   : in unsigned(7 downto 0)   -- byte to write to slave
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

	-- SCL and SDA wire: to change final output from '0' and '1' to '0' and 'X';
	signal scl_wire, sda_wire : std_logic;

	-- input latches: save input on rising edge of start
	signal cmd_reg : unsigned(7 downto 0); -- command = addr + rw
	signal tx_reg : unsigned(7 downto 0);

	-- procedure to latch in new input value
	procedure update is begin
		cmd_reg <= addr & rw;
		tx_reg <= tx;
	end procedure;

	-- SCL enable: release SCL when resetting, idling, starting or stopping
	signal scl_ena : std_logic;

	-- bit count: loop inside state for a byte
	signal cnt : integer range 0 to 7;

begin

	busy <= '1' when state /= idle or rst = '0' else '0';

	-- state machine
	process (clk, rst) begin
		if rst = '0' then
			state <= idle;
		elsif rising_edge(clk) then
			case state is
				when idle =>
					if ena = '1' then
						update;
						state <= start;
					end if;
				when start =>
					state <= cmd;
					cnt <= 7; -- prepare cnt for command state
				when cmd =>
					if cnt = 0 then
						state <= ack1;
					end if;
					cnt <= cnt - 1;
				when ack1 =>
					state <= data;
					cnt <= 7; -- prepare cnt for data state	
				when data =>
					if cnt = 0 then
						state <= ack2;
					end if;
					cnt <= cnt - 1;
				when ack2 =>
					if ena = '1' then -- continuous mode
						update;
						if cmd_reg = addr & rw then
							state <= data; -- keep sending/receiving bytes
						else
							state <= start; -- send a restart
						end if;
					else
						state <= stop;
					end if;
				when stop =>
					state <= idle;
			end case;
		end if;
	end process;

	-- SCL control
	process (clk, rst) begin
		if rst = '0' then
			scl_wire <= '1';
		elsif rising_edge(clk) then
			case state is
				when idle | start | stop =>
					scl_wire <= '1';
				when others =>
					scl_wire <= not scl_wire; -- scl(400kHz) is half the frequency of clk(800kHz)
			end case;
		end if;
	end process;

	-- SDA control
	process (clk) begin
		if rising_edge(clk) then
			if scl_wire = '0' then -- write when SCL is low
				case state is
					when idle =>
						sda_wire <= '1';
					when cmd => -- send 7-bit address plus 1-bit read/write, MSB first
						sda_wire <= cmd_reg(cnt);
					when data =>
						if cmd_reg(0) = '0' then -- r/w bit is write
							sda_wire <= tx_reg(cnt);
						end if;
					when ack2 =>
						if cmd_reg(0) = '1' then -- r/w bit is read
							sda_wire <= '0'; -- send acknowledgment bit
						end if;
					when stop =>
						-- TODO should sda be '0' first?
					when others => null;
				end case;

				-- I2C start/stop and SDA read control
			elsif scl_wire = '1' then -- write start/stop or read when SCL is high
				case state is
					when start =>
						sda_wire <= '0'; -- scl = '1' and falling_edge(sda) == start
					when ack1 =>
						-- TODO handle no acknowledgment, currently ignored
					when data =>
						if cmd_reg(0) = '1' then -- r/w bit is read
							rx(cnt) <= sda_wire; -- cnt is controlled by write process
						end if;
					when ack2 =>
						-- TODO handle no acknowledgment, currently ignored
						if cmd_reg(0) = '0' then -- r/w bit is write
						end if;
					when stop =>
						sda_wire <= '1'; -- scl = '1' and rising_edge(sda) == stop
					when others => null;
				end case;
			end if;
		end if;
	end process;

	-- convert internal wire to open drain
	-- TODO should it include a pull-up ('H') or just high-z ('Z')?
	scl <= 'H' when scl_wire = '1' else '0';
	sda <= 'H' when sda_wire = '1' else '0';

end arch;
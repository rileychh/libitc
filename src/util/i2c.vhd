-- I2C (IIC) master driver
-- based on https://www.digikey.com/eewiki/pages/viewpage.action?pageId=10125324

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.i2c_p.all;
use work.clk_p.all;

entity i2c is
	port (
		-- internal
		clk     : in std_logic;             -- 400kHz
		rst     : in std_logic;             -- low active
		addr    : in unsigned(6 downto 0);  -- slave address
		rw      : in std_logic;             -- high read, low write
		data_tx : in unsigned(7 downto 0);  -- byte to write to slave
		data_rx : out unsigned(7 downto 0); -- byte read from slave
		busy    : out std_logic;            -- if high; addr, rw and data_tx will be ignored
		-- I2C slave
		scl : out std_logic;
		sda : inout std_logic
	);
end i2c;

architecture arch of i2c is

begin

	-- main state machine
	process (clk, rst)

		type state_t is (idle, start, addr, rw, ack1, data, ack2, stop);
		variable state : state_t;

		variable cnt : integer range 0 to 7;

	begin

		if rst = '0' then
			scl <= '1';
			state <= idle;
		elsif rising_edge(clk) then
			case state is
				when idle =>
					sda <= '1';
					state <= start;
				when start =>
					sda <= '0'; -- scl = '1' and falling_edge(sda) == start
					cnt := 6; -- prepare cnt for address state
					state <= addr;
				when addr => -- send 7-bit address, MSB first 
					sda <= addr(cnt);
					if cnt = 0 then
						state <= rw;
					else
						cnt := cnt - 1;
					end if;
				when rw => -- send read / write bit
					sda <= rw;
					state <= ack1;
				when ack1 => -- receive acknowledgment bit
					-- TODO handle no acknowledgment, currently ignored
					cnt := 7 -- prepare cnt for data state	
						state <= data;
				when data =>
					sda <= data(cnt);
					if cnt = 0 then
						state <= ack2;
					else
						cnt := cnt - 1;
					end if;
				when ack2 =>
					-- TODO handle no acknowledgment, currently ignored
					state <= stop;
				when stop =>
					sda <= '1'; -- scl = '1' and rising_edge(sda) == stop
					state <= idle;
			end case;
		end if;

	end process;

end arch;
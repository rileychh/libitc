library ieee;
use ieee.std_logic_1164.all;

use work.itc.all;

entity debounce is
	generic (
		stable_time : integer := 10 -- time sig_in must remain stable in ms
	);
	port (
		-- system
		clk, rst_n : in std_logic;
		-- user logic
		sig_in  : in std_logic; -- input signal to be debounced
		sig_out : out std_logic -- debounced signal
	);
end debounce;

architecture arch of debounce is

	signal prev_sig_ins : std_logic_vector(1 downto 0); -- input flip flops
	signal counter_set : std_logic; -- sync reset to zero

begin

	counter_set <= prev_sig_ins(0) xor prev_sig_ins(1); -- determine when to start/reset counter

	process (clk, rst_n)
		variable cnt : integer range 0 to sys_clk_freq * stable_time / 1000; -- counter for timing
	begin
		if rst_n = '0' then -- reset
			prev_sig_ins(1 downto 0) <= "00"; -- clear input flipflops
			sig_out <= '0'; -- clear result register
		elsif rising_edge(clk) then -- rising clock edge
			prev_sig_ins(0) <= sig_in; -- store sig_in value in 1st flipflop
			prev_sig_ins(1) <= prev_sig_ins(0); -- store 1st flipflop value in 2nd flipflop

			if counter_set = '1' then -- reset counter because input is changing
				cnt := 0; -- clear the counter
			elsif cnt < cnt'high then -- stable input time is not yet met
				cnt := cnt + 1; -- increment counter
			else -- stable input time is met
				sig_out <= prev_sig_ins(1); -- output the stable value
			end if;
		end if;
	end process;

end arch;

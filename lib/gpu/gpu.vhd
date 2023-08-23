-- graphics processing unit for the LCD display

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;

entity gpu is
	port (
		-- system
		clk   : in std_logic;
		rst_n : in std_logic;
		-- lcd
		l_addr : in l_addr_t;
		l_data : out l_px_t;
		-- buffer interface for images and text
		-- b_addr : out l_addr_t; 
		-- b_data : in l_px_t;   
		-- user logic
		pcl  : in integer; -- program counter load
		ena  : in std_logic;
		busy : out std_logic
	);
end gpu;

architecture arch of gpu is

	signal start : std_logic;

	type state is (idle, foo);
begin

	text_prosessor_inst : entity work.text_processor(arch)
		generic map (
			txt_len_max => 16 -- maximum length of text
		);
		port map(
			clk   => clk,
			rst_n => rst_n,
			l_addr
			l_data
			txt_size
			txt_color
			
			txt     : in u8_arr_t(0 to txt_len_max - 1);
			txt_len : in integer range 0 to txt_len_max
			ena
			busy
		);
	image_prosessor_inst : entity work.image_processor(arch)
		port map(
			clk   => clk,
			rst_n => rst_n,
			ena   => ena,
			start => start
		);

	edge_inst : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => ena,
			rising  => start,
			falling => open
		);

	process (clk, rst_n) begin
		if rst_n = '0' then
			state <= idle;
		elsif rising_edge(clk) then
			case state is
				when idle =>
					if start = '1' then
						state <= foo;
					end if;
				when foo =>
					-- do something
				when others =>
					null;
			end case;
		end if;
	end process;

end arch;

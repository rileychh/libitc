--!pp on

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;

entity underline is
	port (
		-- --sys
		clk, rst_n : in std_logic;
		-- sw
		sw : in u8r_t;
		-- lcd
		lcd_sclk, lcd_mosi, lcd_ss_n, lcd_dc, lcd_bl, lcd_rst_n : out std_logic
	);
end underline;

architecture arch of underline is
	signal clk_main : std_logic;
	signal l_addr : l_addr_t;
	signal l_addr_scaled : l_addr_t;
	signal l_data_i : std_logic_vector(23 downto 0);
	signal l_data, paper : l_px_t;
	signal mins : integer range 0 to 59 := 0;
	signal secs : integer range 0 to 59 := 50;
	signal timer_data : string (1 to 5);
	--clk_1hz
	signal clk_1hz, time_clk : std_logic;
	signal lcd_count : integer range 0 to 10;
	signal func_x : integer range 0 to 127;
	signal file_y : integer range 0 to 159;

	type state_t is (idle, background, draw);
	signal state : state_t;

begin

	clk_inst : entity work.clk(arch)
		generic map(
			freq => 1_000_000
		)
		port map(
			clk_in  => clk,
			rst_n   => rst_n,
			clk_out => clk_main
		);
	clk_1hz_inst : entity work.clk(arch)
		generic map(
			freq => 1
		)
		port map(
			clk_in  => clk,
			rst_n   => rst_n,
			clk_out => clk_1hz
		);
	edge_inst : entity work.edge(arch)
		port map(
			clk     => clk_main,
			rst_n   => rst_n,
			sig_in  => clk_1hz,
			rising  => time_clk,
			falling => open
		);
	lcd_inst : entity work.lcd(arch)
		port map(
			clk        => clk,
			rst_n      => rst_n,
			lcd_sclk   => lcd_sclk,
			lcd_mosi   => lcd_mosi,
			lcd_ss_n   => lcd_ss_n,
			lcd_dc     => lcd_dc,
			lcd_bl     => lcd_bl,
			lcd_rst_n  => lcd_rst_n,
			brightness => 100,
			wr_ena     => '1',
			addr       => l_addr,
			data       => l_data
		);

	idle_inst : entity work.idle(SYN)
		port map(
			address => std_logic_vector(to_unsigned(l_addr, 15)),
			clock   => clk,
			q       => l_data_i
		);
	process (clk_main, rst_n) begin
		if rst_n = '0' then

		elsif rising_edge(clk) then
			if l_addr < l_addr'high then
				l_addr <= l_addr + 1;
			else
				l_addr <= 0;
			end if;
			if time_clk = '1' then
				if secs = secs'high then
					secs <= 0;
					if mins = mins'high then
						mins <= 0;
					else
						mins <= mins + 1;
					end if;
				else
					secs <= secs + 1;
				end if;
			end if;
			case sw(6 to 7) is
				when "00" =>
					state <= idle;
				when "01" =>
					state <= draw;
				when others => null;
			end case;
			case state is
				when idle =>
					l_data <= unsigned(l_data_i);
				when background =>
				when draw =>
					timer_data <= to_string(mins, mins'high, 10, 2) & " " & to_string(secs, secs'high, 10, 2);
					case sw(0 to 1) is
						when "00" =>
							func_x <= 28;
							file_y <= 52;
						when "01" =>
							func_x <= 58;
							file_y <= 52;
						when "10" =>
							file_y <= 72;
						when others =>
							func_x <= 88;
					end case;
					--!def T  l_paste_txt(l_addr, time_1s, timer_data, (130, 70))
					--!def time_1s  l_paste_txt(l_addr, Vol," T         :", (130, 2))
					--!def Vol l_paste_txt(l_addr, File_3, " V o l .   : 0 5 ", (110, 2))
					--!def File_3 l_paste_txt(l_addr, File_2, "           : T 3 . w a v ", (90, 2))
					--!def File_2 l_paste_txt(l_addr, File_1, "           : T 2 . w a v ", (70, 2))
					--!def File_1 l_paste_txt(l_addr, File_1_underline,  " F i l e 1 : T 1 . w a v ", (50, 2))
					--!def File_1_underline l_paste_txt(l_addr, title,  "______________", (file_y, 67))
					--!def title l_paste_txt(l_addr, line_txt, "F 1 ,  N  ,  P ", (15, 28))
					--!def line_txt l_paste_txt(l_addr, white, "___", (17, func_x))
					l_data <= l_map(T, black, green);
			end case;

		end if;
	end process;
end arch;

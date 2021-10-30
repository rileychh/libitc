library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;

entity itc110_e1 is
	port (
		-- system
		clk, rst_n : in std_logic;
		-- lcd
		lcd_sclk, lcd_mosi, lcd_ss_n, lcd_dc, lcd_bl, lcd_rst_n : out std_logic;
		-- sw
		sw : in u8r_t;
		-- seg
		seg_led, seg_com : out u8r_t;
		-- key
		key_row : in u4r_t;
		key_col : out u4r_t
	);
end itc110_e1;

architecture arch of itc110_e1 is

	type mode_t is (idle, TFT_lcd_test, start);
	signal sub_mode : integer range 1 to 5;
	type lcd_t is (setup, lcd_scan);
	signal lcd : lcd_t;
	signal mode : mode_t;
	signal ena, wr_ena : std_logic;
	signal addr : l_addr_t;
	signal load, msec : i32_t;
	signal data : l_px_t;
	signal seg_data : string(1 to 8);
	--key
	signal pressed, pressed_i : std_logic;
	signal key : i4_t;
	--seg 
	signal dot : u8_t;

begin
	edge_inst : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => pressed_i,
			rising  => pressed,
			falling => open
		);
	key_inst : entity work.key(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			key_row => key_row,
			key_col => key_col,
			pressed => pressed_i,
			key     => key
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
			addr       => addr,
			data       => data
		);
	seg_inst : entity work.seg(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			seg_led => seg_led,
			seg_com => seg_com,
			data    => seg_data,
			dot     => dot
		);
	timer_inst : entity work.timer(arch)
		port map(
			clk   => clk,
			rst_n => rst_n,
			ena   => ena,
			load  => 0,
			msec  => msec
		);
	process (clk, rst_n)
	begin
		if rst_n = '0' then
			mode <= TFT_lcd_test;
			ena <= '0';
			sub_mode <= 1;
			dot <= x"00";
			seg_data <= "00000000";
		elsif rising_edge(clk) then
			if (addr = addr'high) then
				addr <= 0;
				lcd <= setup;
			else
				addr <= addr + 1;
			end if;
			case mode is
				when idle =>

				when TFT_lcd_test =>
					ena <= '1';
					wr_ena <= '1';
					if msec < 500 then
						data <= white;
					elsif msec < 1_000 then
						data <= black;
					else
						ena <= '0';
						mode <= start;
					end if;
				when start =>
					if sw(6 to 7) = "01" then

						if pressed = '1' then
							dot <= b"00000100";
							case key is
								when 0 =>
									sub_mode <= 1;
								when 4 =>
									if sub_mode + 1 <= 5 then
										sub_mode <= sub_mode + 1;
									end if;
								when 5 =>
									if sub_mode - 1 >= 1 then
										sub_mode <= sub_mode - 1;
									end if;
								when others =>
									null;
							end case;
							case sub_mode is
								when 1 =>
									data <= red;
									seg_data <= "ModE0000";
								when 2 =>
									seg_data <= "ModE0100";
								when 3 =>
									seg_data <= "ModE0200";
								when 4 =>
									seg_data <= "ModE0227";
								when 5 =>
									seg_data <= "ModE0375";
								when others => null;
							end case;

						end if;
					end if;
				when others =>
					null;
			end case;
		end if;
	end process;
end arch;

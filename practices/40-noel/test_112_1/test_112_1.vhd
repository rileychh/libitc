library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;

entity test_112_1 is
	port (
		-- system
		clk, rst_n : in std_logic;
		-- lcd
		lcd_sclk, lcd_mosi, lcd_ss_n, lcd_dc, lcd_bl, lcd_rst_n : out std_logic;
		-- key
		key_row : in u4r_t;
		key_col : out u4r_t
	);
end test_112_1;

architecture arch of test_112_1 is

	signal l_wr_ena : std_logic;
	signal l_addr : l_addr_t;
	signal l_data : l_px_t;
begin
	lcd_inst: entity work.lcd(arch)
	port map (
		clk => clk,
		rst_n => rst_n,
		lcd_sclk => lcd_sclk,
		lcd_mosi => lcd_mosi,
		lcd_ss_n => lcd_ss_n,
		lcd_dc => lcd_dc,
		lcd_bl => lcd_bl,
		lcd_rst_n => lcd_rst_n,
		brightness => 100,
		wr_ena => wr_ena,
		addr => addr,
		data => data 
	);

	key_inst: entity work.key(arch)
	port map (
		clk => clk,
		rst_n => rst_n,
		key_row => key_row,
		key_col => key_col,
		pressed => pressed,
		key => key 
	);
end arch;
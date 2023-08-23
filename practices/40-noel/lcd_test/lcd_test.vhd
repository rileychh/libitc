library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;

entity lcd_test is
	port (
		clk                                                     : in std_logic;
		rst_n                                                   : in std_logic;
		lcd_sclk, lcd_mosi, lcd_ss_n, lcd_dc, lcd_bl, lcd_rst_n : out std_logic;
		key_row                                                 : in u4r_t;
		key_col                                                 : out u4r_t);
end lcd_test;

architecture arch of lcd_test is
	signal clk1000, clk_1000 : std_logic;
	signal abc : integer;

	signal x : integer range -127 to 127;
	signal y : integer range -159 to 159;
	signal font_start, font_busy, draw_done : std_logic;
	signal text_data : string(1 to 12);
	signal bg_color : l_px_t;
	signal text_color_array : l_px_arr_t(1 to 12);
	signal lcd_clear : std_logic;
	signal con : std_logic;
	signal pic_addr : l_addr_t;
	signal pic_data : std_logic_vector(23 downto 0);
	signal lcd_count : integer;
	constant all_green : l_px_arr_t(1 to 12) := (green, green, green, green, green, green, green, green, green, green, green, green);
	constant all_red : l_px_arr_t(1 to 12) := (red, red, red, red, red, red, red, red, red, red, red, red);
	constant all_blue : l_px_arr_t(1 to 12) := (blue, blue, blue, blue, blue, blue, blue, blue, blue, blue, blue, blue);

	signal key_data : i4_t;
	signal pressed_i, key_pressed : std_logic;
begin
	edge_inst : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => clk1000,
			rising  => clk_1000,
			falling => open
		);
	clk_inst : entity work.clk(arch)
		generic map(
			freq => 1000
		)
		port map(
			clk_in  => clk,
			rst_n   => rst_n,
			clk_out => clk1000
		);
	edge_key_inst : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => pressed_i,
			rising  => key_pressed,
			falling => open
		);
	key_inst : entity work.key(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			key_row => key_row,
			key_col => key_col,
			pressed => pressed_i,
			key     => key_data
		);
	edge_draw_inst : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => font_busy,
			rising  => open,
			falling => draw_done
		);
	bongo_inst : entity work.bongo(syn)
		port map(
			address => std_logic_vector(to_unsigned(pic_addr, 15)),
			clock   => clk,
			q       => pic_data
		);
	lcd_mix_inst : entity work.lcd_mix(arch)
		port map(
			clk              => clk,
			rst_n            => rst_n,
			x                => x,
			y                => y,
			font_start       => font_start,
			font_busy        => font_busy,
			text_size        => 1,
			text_data        => text_data,
			text_count       => open,
			addr             => open,
			text_color       => green,
			bg_color         => bg_color,
			text_color_array => text_color_array,
			clear            => lcd_clear,
			lcd_sclk         => lcd_sclk,
			lcd_mosi         => lcd_mosi,
			lcd_ss_n         => lcd_ss_n,
			lcd_dc           => lcd_dc,
			lcd_bl           => lcd_bl,
			lcd_rst_n        => lcd_rst_n,
			con              => con,
			pic_addr         => pic_addr,
			pic_data         => pic_data
		);
	process (clk, rst_n)
	begin
		if rst_n = '0' then
			abc <= 0;
			font_start <= '0';
			con <= '0';
			bg_color <= white;
			lcd_count <= 0;
			x <= 0;
			y <= 10;
			lcd_clear <= '1';
		elsif rising_edge(clk) then
			bg_color <= white;
			lcd_clear <= '0';
			if key_pressed = '1' then
				if abc /= 9 then
					-- x <= x + 10;
					abc <= abc + 1;
				else
					-- x <= 0;
					abc <= 0;
				end if;
			end if;
			if y = 10 and draw_done = '0' then
				text_data <= to_string(abc, 9, 10, 1) & "           ";
				if abc = 0 or abc = 3 or abc = 6 or abc = 9 then
					text_color_array <= all_green;
				elsif abc = 1 or abc = 4 or abc = 7 then
					text_color_array <= all_red;
				elsif abc = 2 or abc = 5 or abc = 8 then
					text_color_array <= all_blue;
				end if;
				font_start <= '1';
			elsif draw_done = '1' then
				font_start <= '0';
				y <= 10;
			end if;
		end if;
	end process;
end arch;

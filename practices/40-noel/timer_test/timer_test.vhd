library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;

entity timer_test is
	port (
		clk   : in std_logic;
		rst_n : in std_logic;
		--sw
		sw : in u8r_t;
		--key
		key_row : in u4r_t;
		key_col : out u4r_t;
		--lcd
		lcd_sclk, lcd_mosi, lcd_ss_n, lcd_dc, lcd_bl, lcd_rst_n : out std_logic
	);
end timer_test;

architecture arch of timer_test is
	--system
	signal clk_1, clk1 : std_logic;
	signal mod0, mod1 : std_logic;
	type mode_t is (clear, count, stop);
	signal mode : mode_t;

	signal start_flag, clear_flag : std_logic;
	--key
	signal key_data : i4_t;
	signal pressed, key_pressed : std_logic;
	--lcd
	signal x : integer range -127 to 127;
	signal pic_y, text_y, y : integer range -159 to 159;
	signal font_start, font_busy, draw_done : std_logic;
	signal text_data : string(1 to 12);
	signal bg_color, pic_data : l_px_t;
	signal text_color_array : l_px_arr_t(1 to 12);
	signal lcd_clear : std_logic;
	signal l_addr : l_addr_t;
	signal lcd_count : integer range 0 to 2;
	signal sivs_addr : l_addr_t;
	signal sivs_data_in : std_logic_vector(23 downto 0);
	signal sivs_data : l_px_t;
	--timer
	signal second, minute : integer range 0 to 100;
	signal hour : integer range 0 to 24;

	constant all_green : l_px_arr_t(1 to 12) := (green, green, green, green, green, green, green, green, green, green, green, green);

begin
	clk_inst : entity work.clk(arch)
		generic map(
			freq => 100
		)
		port map(
			clk_in  => clk,
			rst_n   => rst_n,
			clk_out => clk_1
		);
	edge_clk_1_inst : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => clk_1,
			rising  => clk1,
			falling => open
		);
	edge_sw_inst : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => sw(7),
			rising  => mod1,
			falling => mod0
		);
	key_inst : entity work.key(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			key_row => key_row,
			key_col => key_col,
			pressed => pressed,
			key     => key_data
		);
	edge_key_pressed_inst : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => pressed,
			rising  => key_pressed,
			falling => open
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
			addr             => l_addr,
			text_color       => green,
			bg_color         => bg_color,
			text_color_array => text_color_array,
			clear            => lcd_clear,
			con              => '0',
			pic_data         => pic_data,
			lcd_sclk         => lcd_sclk,
			lcd_mosi         => lcd_mosi,
			lcd_ss_n         => lcd_ss_n,
			lcd_dc           => lcd_dc,
			lcd_bl           => lcd_bl,
			lcd_rst_n        => lcd_rst_n
		);
	edge_lcd_inst : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => font_busy,
			rising  => open,
			falling => draw_done
		);
	SIVS_inst : entity work.SIVS(syn)
		port map(
			address => std_logic_vector(to_unsigned(sivs_addr, 14)),
			clock   => clk,
			q       => sivs_data_in
		);
	sivs_data <= unsigned(sivs_data_in);
	process (clk, rst_n)
	begin
		if rst_n = '0' then
			start_flag <= '0';
			second <= 0;
			minute <= 0;
			hour <= 0;
			lcd_count <= 0;
			font_start <= '0';
			pic_y <= 0;
			text_y <= 115;
			mode <= clear;
		elsif rising_edge(clk) then
			if key_pressed = '1' and key_data = 0 then
				if mode = count then
					mode <= stop;
				else
					mode <= count;
				end if;
			elsif key_pressed = '1' and key_data = 1 and mode = stop then
				clear_flag <= '1';
				mode <= clear;
			end if;
			if mod1 = '1' then
				pic_y <= 81;
				text_y <= 35;
				lcd_count <= 0;
			elsif mod0 = '1' then
				pic_y <= 0;
				text_y <= 115;
				lcd_count <= 0;
			end if;
			case mode is
				when clear =>
					second <= 0;
					minute <= 0;
					hour <= 0;
				when count =>
					if clk1 = '1' then
						if second < 99 then
							second <= second + 1;
						else
							second <= 0;
							if minute < 59 then
								minute <= minute + 1;
							else
								minute <= 0;
								if hour < 23 then
									hour <= hour + 1;
								else
									hour <= 0;
								end if;
							end if;
						end if;
					end if;
				when stop =>
			end case;
			bg_color <= to_data(l_paste(l_addr, white, sivs_data, (pic_y, -10), 128, 80));
			sivs_addr <= to_addr(l_paste(l_addr, white, sivs_data, (pic_y, -10), 128, 80));
			case lcd_count is
				when 0 =>
					lcd_clear <= '1';
					if draw_done = '1' then
						lcd_count <= 1;
						font_start <= '0';
						text_color_array <= all_green;
					end if;
				when 1 =>
					lcd_clear <= '0';
					x <= 5;
					y <= text_y;
					text_data <= "  " & to_string(hour, 24, 10, 2) & ":" & to_string(minute, 60, 10, 2) & ":" & to_string(second, 60, 10, 2) & "  ";
					font_start <= '1';
					if draw_done = '1' then
						lcd_count <= 1;
						font_start <= '0';
					end if;
				when 2 =>
			end case;
		end if;
	end process;
end arch;

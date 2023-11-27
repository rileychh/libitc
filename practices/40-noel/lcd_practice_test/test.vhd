library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;

entity test is
	port (
		clk   : in std_logic;
		rst_n : in std_logic;
		-- LCD
		lcd_sclk, lcd_mosi, lcd_ss_n, lcd_dc, lcd_bl, lcd_rst_n : out std_logic;
		-- key
		key_row : in u4r_t;
		key_col : out u4r_t;
		-- seg
		seg_led, seg_com : out u8r_t

	);
end test;

architecture arch of test is
	signal clk_3, clk_3hz : std_logic;

	signal x : integer range -127 to 127;
	signal y : integer range -159 to 159;
	signal font_start, font_busy, draw_done : std_logic;
	signal text_data : string(1 to 12);
	signal bg_color : l_px_t;
	signal text_color_array : l_px_arr_t(1 to 12);
	signal clear : std_logic;
	signal con : std_logic;
	signal pic_addr, pic_addr_out, l_addr, pic_addr_1, pic_addr_2, pic_addr_all_page : l_addr_t;
	signal pic_data, all_page, green1, green2, green3, green4, green5, green6, green7, green8, green9, mem_data : l_px_t;
	signal lcd_count : integer range 0 to 5;
	signal all_page_in, green1_in, green2_in, green3_in, green4_in, green5_in, green6_in, green7_in, green8_in, green9_in : std_logic_vector(23 downto 0);
	signal lcd_count_m : integer range 0 to 5;
	signal wr_ena : std_logic;
	signal abc : integer range 0 to 200;
	signal flag, flag2 : std_logic;

	signal data : string(1 to 8);
	signal dot : u8r_t;

	signal t_ena : std_logic;
	signal msec : i32_t;

	signal pressed, key_pressed : std_logic;
	signal key_data : i4_t;

	constant all_green : l_px_arr_t(1 to 12) := (green, green, green, green, green, green, green, green, green, green, green, green);
	constant all_red : l_px_arr_t(1 to 12) := (red, red, red, red, red, red, red, red, red, red, red, red);
	constant test_col : l_px_arr_t(1 to 12) := (red, green, black, yellow, blue, green, red, green, black, yellow, blue, red);
begin
	clk_inst : entity work.clk(arch)
		generic map(
			freq => 3
		)
		port map(
			clk_in  => clk,
			rst_n   => rst_n,
			clk_out => clk_3
		);
	edge_clk1_inst : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => clk_3,
			rising  => clk_3hz,
			falling => open
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
	edge_key_inst : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => pressed,
			rising  => key_pressed,
			falling => open
		);
	timer_inst : entity work.timer(arch)
		port map(
			clk   => clk,
			rst_n => rst_n,
			ena   => t_ena,
			load  => 0,
			msec  => msec
		);
	seg_inst : entity work.seg(arch)
		generic map(
			common_anode => '1'
		)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			seg_led => seg_led,
			seg_com => seg_com,
			data    => data,
			dot     => dot
		);
	edge_inst : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => font_busy,
			rising  => open,
			falling => draw_done
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
			clear            => clear,
			con              => con,
			-- pic_addr         => pic_addr,
			pic_data  => pic_data,
			lcd_sclk  => lcd_sclk,
			lcd_mosi  => lcd_mosi,
			lcd_ss_n  => lcd_ss_n,
			lcd_dc    => lcd_dc,
			lcd_bl    => lcd_bl,
			lcd_rst_n => lcd_rst_n
		);
	-- green1_inst : entity work.green1(syn)
	-- 	port map(
	-- 		address => std_logic_vector(to_unsigned(pic_addr_1, 9)),
	-- 		clock   => clk,
	-- 		q       => green1_in
	-- 	);
	-- green2_inst : entity work.green2(syn)
	-- 	port map(
	-- 		address => std_logic_vector(to_unsigned(pic_addr_out, 9)),
	-- 		clock   => clk,
	-- 		q       => green2_in
	-- 	);
	-- green3_inst : entity work.green3(syn)
	-- 	port map(
	-- 		address => std_logic_vector(to_unsigned(pic_addr_2, 9)),
	-- 		clock   => clk,
	-- 		q       => green3_in
	-- 	);
	-- green4_inst : entity work.green4(syn)
	-- 	port map(
	-- 		address => std_logic_vector(to_unsigned(pic_addr_out, 15)),
	-- 		clock   => clk,
	-- 		q       => green4_in
	-- 	);
	-- all_page_inst : entity work.all_page(syn)
	-- 	port map(
	-- 		address => std_logic_vector(to_unsigned(pic_addr_all_page, 15)),
	-- 		clock   => clk,
	-- 		q       => all_page_in
	-- 	);

	green1 <= unsigned(green1_in);

	green3 <= unsigned(green3_in);
	green4 <= unsigned(green4_in);
	all_page <= unsigned(all_page_in);
	process (clk, rst_n)
	begin
		if rst_n = '0' then
			t_ena <= '0';
			clear <= '1';
			lcd_count_m <= 0;
			lcd_count <= 0;
			dot <= "00000000";
			y <= 0;
			wr_ena <= '0';
			data <= "        ";
			abc <= 0;
		elsif rising_edge(clk) then
			if msec < 2000 then
				t_ena <= '1';
			else
				t_ena <= '0';
			end if;
			case lcd_count is
				when 0 =>
					con <= '0';
					clear <= '1';
					bg_color <= white;
					if draw_done = '1' then
						lcd_count <= 1;
						font_start <= '0';
						clear <= '0';
					end if;
				when 1 =>
					x <= 5;
					y <= 10;
					text_data <= "+-x/!?=$#&%*";
					font_start <= '1';
					if draw_done = '1' then
						lcd_count <= 2;
						font_start <= '0';
					end if;
				when 2 =>
					y <= 30;
					text_data <= "\_-'~()^|.,>";
					font_start <= '1';
					if draw_done = '1' then
						lcd_count <= 3;
						font_start <= '0';
					end if;
				when 3 =>
					y <= 50;
					text_data <= "{}<:; @     ";
					font_start <= '1';
					if draw_done = '1' then
						lcd_count <= 1;
						font_start <= '0';
					end if;
				when 4 =>
				when 5 =>
				when others =>
			end case;
		end if;
	end process;
end arch;

clk_inst : entity work.clk(arch)
	generic map(
		freq => 1_000_000
	)
	port map(
		clk_in  => clk,
		rst_n   => rst_n,
		clk_out => clk_main
	);

timer_inst : entity work.timer(arch)
	port map(
		clk   => clk,
		rst_n => rst_n,
		ena   => timer_ena,
		load  => timer_load,
		msec  => msec
	);

key_inst : entity work.key(arch)
	port map(
		clk     => clk,
		rst_n   => rst_n,
		key_row => key_row,
		key_col => key_col,
		pressed => pressed,
		key     => key
	);

edge_inst : entity work.edge(arch)
	port map(
		clk     => clk_main,
		rst_n   => rst_n,
		sig_in  => pressed,
		rising  => key_on_press,
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
		wr_ena     => l_wr_ena,
		addr       => l_addr,
		data       => l_data
	);

seg_inst : entity work.seg(arch)
	port map(
		clk     => clk,
		rst_n   => rst_n,
		seg_led => seg_led,
		seg_com => seg_com,
		data    => seg_data,
		dot     => seg_dot
	);

dht_inst : entity work.dht(arch)
	port map(
		clk      => clk,
		rst_n    => rst_n,
		dht_data => dht_data,
		temp_int => temp_int,
		hum_int  => hum_int,
		temp_dec => temp_dec,
		hum_dec  => hum_dec
	);

tsl_inst : entity work.tsl(arch)
	port map(
		tsl_scl => tsl_scl,
		tsl_sda => tsl_sda,
		clk     => clk,
		rst_n   => rst_n,
		lux     => lux
	);

mot_inst : entity work.mot(arch)
	port map(
		clk     => clk,
		rst_n   => rst_n,
		mot_ch  => mot_ch,
		mot_ena => mot_ena,
		dir     => dir,
		speed   => speed
	);

tts_inst : entity work.tts(arch)
	generic map(
		txt_len_max => 64
	)
	port map(
		clk       => clk,
		rst_n     => rst_n,
		tts_scl   => tts_scl,
		tts_sda   => tts_sda,
		tts_mo    => tts_mo,
		tts_rst_n => tts_rst_n,
		ena       => tts_ena,
		busy      => tts_busy,
		txt       => tts_data,
		txt_len   => tts_len
	);

digit_9_inst : entity work.digit_9(syn)
	port map(
		address => std_logic_vector(to_unsigned(digit_addr(9), 15)),
		clock   => clk,
		q       => digit_data_i(9)
	);

digit_8_inst : entity work.digit_8(syn)
	port map(
		address => std_logic_vector(to_unsigned(digit_addr(8), 15)),
		clock   => clk,
		q       => digit_data_i(8)
	);

digit_7_inst : entity work.digit_7(syn)
	port map(
		address => std_logic_vector(to_unsigned(digit_addr(7), 15)),
		clock   => clk,
		q       => digit_data_i(7)
	);

digit_6_inst : entity work.digit_6(syn)
	port map(
		address => std_logic_vector(to_unsigned(digit_addr(6), 15)),
		clock   => clk,
		q       => digit_data_i(6)
	);

digit_5_inst : entity work.digit_5(syn)
	port map(
		address => std_logic_vector(to_unsigned(digit_addr(5), 15)),
		clock   => clk,
		q       => digit_data_i(5)
	);

digit_4_inst : entity work.digit_4(syn)
	port map(
		address => std_logic_vector(to_unsigned(digit_addr(4), 15)),
		clock   => clk,
		q       => digit_data_i(4)
	);

digit_3_inst : entity work.digit_3(syn)
	port map(
		address => std_logic_vector(to_unsigned(digit_addr(3), 15)),
		clock   => clk,
		q       => digit_data_i(3)
	);

digit_2_inst : entity work.digit_2(syn)
	port map(
		address => std_logic_vector(to_unsigned(digit_addr(2), 15)),
		clock   => clk,
		q       => digit_data_i(2)
	);

digit_1_inst : entity work.digit_1(syn)
	port map(
		address => std_logic_vector(to_unsigned(digit_addr(1), 15)),
		clock   => clk,
		q       => digit_data_i(1)
	);

digit_0_inst : entity work.digit_0(syn)
	port map(
		address => std_logic_vector(to_unsigned(digit_addr(0), 15)),
		clock   => clk,
		q       => digit_data_i(0)
	);

digit_data_assign : for i in 0 to 9 generate
	digit_data(i) <= digit_data_i(i)(0);
end generate digit_data_assign;

sensor_bg_inst : entity work.sensor_bg(syn)
	port map(
		address => std_logic_vector(to_unsigned(l_addr, 15)),
		clock   => clk,
		q       => sensor_bg_data_i
	);
sensor_bg_data <= repeat(sensor_bg_data_i(2), 8) & repeat(sensor_bg_data_i(1), 8) & repeat(sensor_bg_data_i(0), 8);

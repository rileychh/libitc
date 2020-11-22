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
		clk     => clk,
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
		brightness => brightness,
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
		temp_int => temp,
		hum_int  => open,
		temp_dec => open,
		hum_dec  => open
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

bg_inst : entity work.bg(syn)
	port map(
		address => std_logic_vector(to_unsigned(bg_addr, 15)),
		clock   => clk,
		q       => bg_data_i
	);

icon_inst : entity work.icon(syn)
	port map(
		address => std_logic_vector(to_unsigned(icon_addr, 10)),
		clock   => clk,
		q       => icon_data_i
	);

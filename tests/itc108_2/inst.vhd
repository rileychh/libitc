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
		wr_ena     => lcd_wr_ena,
		addr       => pixel_addr,
		data       => pixel_data
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
--fuck this
uart_inst : entity work.uart(arch)
	generic map(
		baud => 9600
	)
	port map(
		clk     => clk,
		rst_n   => rst_n,
		uart_rx => uart_rx,
		uart_tx => uart_tx,
		tx_ena  => tx_ena,
		tx_busy => tx_busy,
		tx_data => tx_data,
		rx_busy => rx_busy,
		rx_err  => rx_err,
		rx_data => rx_data
	);

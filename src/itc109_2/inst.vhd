key_inst : entity work.key(arch)
	port map(
		clk     => clk,
		rst_n   => rst_n,
		key_row => key_row,
		key_col => key_col,
		pressed => pressed,
		key     => key
	);

edge_inst_rx : entity work.edge(arch)
	port map(
		clk     => clk,
		rst_n   => rst_n,
		sig_in  => pressed,
		rising  => key_on_press,
		falling => open
	);

dot_inst : entity work.dot(arch)
	generic map(
		common_anode => '0'
	)
	port map(
		clk       => clk,
		rst_n     => rst_n,
		dot_red   => dot_red,
		dot_green => dot_green,
		dot_com   => dot_com,
		data_r    => dot_r,
		data_g    => dot_g
	);

seg_inst : entity work.seg(arch)
	generic map(
		common_anode => '0'
	)
	port map(
		clk     => clk,
		rst_n   => rst_n,
		seg_led => seg_led,
		seg_com => seg_com,
		data    => seg_data,
		dot     => seg_dot
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
		brightness => l_bl,
		wr_ena     => l_ena,
		addr       => l_addr,
		data       => l_data
	);

rgb_inst : entity work.rgb(arch)
	port map(
		clk   => clk,
		rst_n => rst_n,
		rgb   => rgb,
		color => rgb_color
	);

sw_inst : entity work.sw(arch)
	port map(
		clk     => clk,
		rst_n   => rst_n,
		sw      => sw,
		sw_out  => sw_i,
		rising  => sw_rising,
		falling => sw_falling
	);

timer_inst : entity work.timer(arch)
	port map(
		clk   => clk,
		rst_n => rst_n,
		ena   => timer_ena,
		load  => timer_load,
		msec  => msec
	);

uart_txt_inst : entity work.uart_txt(arch)
	generic map(
		txt_len_max => 64,
		baud        => 9600
	)
	port map(
		clk     => clk,
		rst_n   => rst_n,
		uart_rx => uart_rx,
		uart_tx => uart_tx,
		tx_ena  => tx_ena,
		tx_busy => tx_busy,
		tx_data => tx_data,
		tx_len  => tx_len,
		rx_busy => rx_busy,
		rx_data => rx_data,
		rx_len  => rx_len
	);

edge_inst : entity work.edge(arch)
	port map(
		clk     => clk,
		rst_n   => rst_n,
		sig_in  => rx_busy,
		rising  => open,
		falling => rx_done
	);

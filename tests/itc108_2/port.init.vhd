port (
	-- sys
	clk, rst_n : in std_logic;
	-- sw
	sw : in u8r_t;
	-- key
	key_row : in u4r_t;
	key_col : out u4r_t;
	-- dht
	dht_data : inout std_logic;
	-- lcd
	lcd_sclk, lcd_mosi, lcd_ss_n, lcd_dc, lcd_bl, lcd_rst_n : out std_logic;
	-- seg
	seg_led, seg_com : out u8r_t;
	-- mot
	mot_ch  : out u2r_t;
	mot_ena : out std_logic;

	-- uart
	uart_rx : in std_logic;  -- receive pin
	uart_tx : out std_logic; -- transmit pin

	-- dot
	dot_red, dot_green, dot_com : out u8r_t
);

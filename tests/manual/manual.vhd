library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;
----------------------------------------------------------------------definition
-- u2_t 		= unsigned(1 downto 0)
-- u2r_t 		= unsigned(0 to 1)
-- u2_arr_t 	= integer (1 downto x)	(least x = 0)
-- u2r_arr_t 	= integer (0 to x)		(biggest x = 1)

-- u4_t 		= unsigned(3 downto 0)
-- u4r_t 		= unsigned(0 to 3);
-- u4_arr_t 	= integer (3 downto x)	(least x = 0)
-- u4r_arr_t	= integer (0 to x)		(biggest x = 3)

-- u8_t			= unsigned(7 downto 0)
-- u8r_t		= unsigned(0 to 7);
-- u8_arr_t		= integer (7 downto x)	(least x = 0)
-- u8r_arr_t	= integer (0 to x)		(biggest x = 7)

-- u16_t 		= unsigned(15 downto 0)
-- u16r_t		= unsigned(0 to 15);
-- u16_arr_t	= integer (15 downto x)	(least x = 0)
-- u16r_arr_t	= integer (0 to x)		(biggest x = 15)

-- i32_t 		= integer (0 to ∞)
-- i32_arr_t 	= integer (∞ downto x)  (least x = 0)

----------------------------------------------------------------------function 
--to_string(num, num_max, base, length : integer) return string;

----------------------------------------------------------------------sw,seg,dht11,key,lcd
entity manual is
	port
	(
		clk, rst_n : in std_logic;

		-- sw
		sw : in u8r_t;

		--led(r g y)
		led_r, led_g, led_y : out std_logic;
		
		-- dht
		dht_data : inout std_logic;

		--seg
		seg_led, seg_com : out u8r_t;
		
		-- key
		key_row : in u4r_t;
		key_col : out u4r_t;

		--8*8 dot led
		dot_red, dot_green, dot_com : out u8r_t;

		-- tsl
		tsl_scl, tsl_sda : inout std_logic;

		-- tts
		tts_scl, tts_sda : inout std_logic;
		tts_mo           : in unsigned(2 downto 0);
		dbg_b			 : out u8r_t;
		tts_rst_n        : out std_logic;

		--buzzer
		buz : out std_logic;		--'1' 叫  '0' 不叫

		--uart
		uart_rx : in std_logic;  -- receive pin
		uart_tx : out std_logic; -- transmit pin
		dbg_b   : out u8r_t;

		-- lcd
		lcd_sclk, lcd_mosi, lcd_ss_n, lcd_dc, lcd_bl, lcd_rst_n : out std_logic
	);
end manual;

architecture rtl of manual is
------------------------------------------------------------------signal
--buz
signal buz_ena,buz_flag : std_logic;
signal buz_busy,buz_done: std_logic;

--seg
signal seg_data:string(1 to 8):=(others=>' ');
signal dot:u8r_t:=(others=>'0');

--key
signal pressed, pressed_i : std_logic;
signal key : i4_t;

--dht11
signal temp_int, hum_int : integer range 0 to 99;

--tsl
signal lux : i16_t;

--f(1khz)
signal msec,load:i32_t;
signal timer_ena:std_logic;

--lcd_draw
signal bg_color, text_color : l_px_t;
signal addr : l_addr_t;
signal data : string(1 to 12);
signal font_start,font_busy,lcd_clear : std_logic;
signal draw_done : std_logic;
signal x, y : integer range 0 to 159;

--lcd_inst
signal brightness : integer range 0 to 100;
signal l_wr_ena : std_logic;
signal l_addr : l_addr_t;
signal l_data : l_px_t;
signal icon_addr : integer range 0 to l_px_cnt - 1;
signal icon_data_i : std_logic_vector(0 downto 0);
signal icon_data : l_px_t;

--8*8 dot led
constant data_wang : u8r_arr_t(0 to 7) := (x"00", x"7C", x"10", x"38", x"10", x"7C", x"00", x"00"); --王
signal data_g, data_r : u8r_arr_t(0 to 7);

--tts
signal tts_ena : std_logic;
signal busy : std_logic;
constant max_len : integer := 100;
signal txt : u8_arr_t(0 to max_len - 1);
signal len : integer range 0 to max_len;
signal tts_done : std_logic;
type tts_mode_t is (idle,tts_play,stop);
signal tts_mode : tts_mode_t;

--uart
signal tx_data, rx_data : u8_t := x"00";
signal rx_start, rx_done : std_logic;
signal tx_ena, tx_busy, rx_busy, rx_err : std_logic;
------------------------------------------------------------------end signal
begin
----------------------------------------begin packages
	clk_inst : entity work.clk(arch)
		generic map(
			freq => 1				--頻率
		)
		port map(
			clk_in  => clk,
			rst_n   => rst_n,
			clk_out => clk_out		--輸出
		);
	dht_inst : entity work.dht(arch)
		port map(
			clk      => clk,
			rst_n    => rst_n,
			dht_data => dht_data,	--腳位 資料輸入/出
			temp_int => temp_int,	--輸出溫度(integer)
			temp_dec => open,		--輸出溫度(binary)
			hum_int  => hum_int,	--輸出濕度(integer)
			hum_dec  => open		--輸出濕度(binary)
		);
	tsl_inst : entity work.tsl(arch)
		port map(
			tsl_scl => tsl_scl,		--腳位
			tsl_sda => tsl_sda,		--腳位
			clk     => clk,
			rst_n   => rst_n,
			lux     => lux			--輸出亮度(integer)
		);
	seg_inst : entity work.seg(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			seg_led => seg_led,		--腳位 a~g
			seg_com => seg_com,		--共同腳位
			data    => seg_data,	--七段資料 輸入要顯示字元即可,遮末則輸入空白
			dot     => dot			--小數點 1 亮
									--輸入資料ex: b"01000000" = x"70"  
									--seg_deg 度C
		);
	key_inst : entity work.key(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			key_row => key_row,		--腳位
			key_col => key_col,		--腳位
			pressed => pressed_i,	--pressed='1' 代表按住
			key     => key			--key=0 代表按下 key 1	key=1 代表按下 key 2...........
		);
	timer_inst : entity work.timer(arch)
		port map(
			clk   => clk,
			rst_n => rst_n,		
			ena   => timer_ena,			--當ena='0', msec=load
			load  => load,				--起始值
			msec  => msec			--毫秒數
		);
	edge_inst : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => pressed_i,	--輸入訊號(通常用在 4*4 keypad或計數)
			rising  => pressed,		--正緣 '1'觸發
			falling => open			--負緣 open=開路
		);
	lcd_draw : entity work.gen_font(arch)--lcd 文字
		port map(
			clk        => clk,
			rst_n      => rst_n,
			x          => x,			-- 橫
			y          => y,			-- 縱
			font_start => font_start,	-- 畫面更新頻率(取正緣)
			font_busy  => font_busy,	-- 當畫面正在更新時，font_busy='1';
			text_size  => 1,			-- 字體大小
			data       => data,			-- 資料
			text_color => black,		-- 字體顏色
			addr       => open,			-- 偵錯用
			bg_color   => white,		-- 背景顏色 black blue red magenta green cyan yellow white 
			clear      => lcd_clear,	-- 1 清除
			lcd_sclk   => lcd_sclk,		-- 腳位
			lcd_mosi   => lcd_mosi,		-- 腳位
			lcd_ss_n   => lcd_ss_n,		-- 腳位
			lcd_dc     => lcd_dc,		-- 腳位
			lcd_bl     => lcd_bl,		-- 腳位
			lcd_rst_n  => lcd_rst_n		-- 腳位

		);

	lcd_inst : entity work.lcd(arch)--lcd 背景掃描
		port map(
			clk        => clk,			
			rst_n      => rst_n,		
			lcd_sclk   => lcd_sclk,		-- 腳位
			lcd_mosi   => lcd_mosi,		-- 腳位
			lcd_ss_n   => lcd_ss_n,		-- 腳位
			lcd_dc     => lcd_dc,		-- 腳位
			lcd_bl     => lcd_bl,		-- 腳位
			lcd_rst_n  => lcd_rst_n,	-- 腳位
			brightness => 100,			-- 亮度0~100
			wr_ena     => l_wr_ena,		-- enable 1動作
			addr       => l_addr,		-- 
			data       => l_data		-- 背景顏色 black blue red magenta green cyan yellow white 
		);
	dot_inst : entity work.dot(arch)
		generic map(
				common_anode => '0'
			)
		port map(
			clk       => clk,			
			rst_n     => rst_n,			
			dot_red   => dot_red,		--腳位
			dot_green => dot_green,		--腳位
			dot_com   => dot_com,		--腳位
			data_r    => data_r,		--紅色資料
			data_g    => data_g			--綠色資料
		);
			--若要顯示橘色，將相同資料同時放入data_r,data_g即可
			--資料由下而上由左而右 u8r_arr_t(0 to 7) :=(x"00", x"7C", x"10", x"38", x"10", x"7C", x"00", x"00");
			-- 7  。。。。。。。。
			-- 6  。．．．．．。。
			-- 5  。。。．。。。。
			-- 4  。。．．．。。。
			-- 3  。。。．。。。。
			-- 2  。．．．．．。。
			-- 1  。。。。。。。。
			-- 0  。。。。。。。。
		
	tts_inst: entity work.tts(arch)
		generic map (
				txt_len_max => max_len
			)
		port map (
			clk => clk,
			rst_n => rst_n,
			tts_scl => tts_scl,			--腳位
			tts_sda => tts_sda,			--腳位
			tts_mo => tts_mo,			--腳位
			tts_rst_n => tts_rst_n,		--腳位
			ena => tts_ena,				--enable 1致能
			busy => busy,				--播報時busy='1'
			txt => txt,					--data(編碼產生=>tool=>tts.py=>compile=>輸入數目=>輸入名字=>輸入播報內容)
			txt_len => len				--
		);
	uart_inst : entity work.uart(arch)
		generic map(
			baud => 9600
		)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			uart_rx => uart_rx,		--腳位
			uart_tx => uart_tx,		--腳位
			tx_ena  => tx_ena,		--enable '1' 動作
			tx_busy => tx_busy,		--tx資料傳送時tx_busy='1'
			tx_data => tx_data,		--硬體要傳送的資料 
			rx_busy => rx_busy,		--rx資料傳送時rx_busy='1'
			rx_err  => rx_err,		--檢測錯誤
			rx_data => rx_data		--由軟體接收到的資料 
		);
	buzzer_inst : entity work.buzzer(arch)
		port map
		(
			clk=>clk,
			rst_n=>rst_n,
			buz=>buz,				--腳位
			ena=>buz_ena,			--enable '1' 動作
			mode_flag=>buz_flag,    --'0' 短音   '1' 長音
			busy=>buz_busy			--發聲時busy='1'
		);
---------------------------------------end packages
	Process(clk,rst_n)
	begin
		-- 軟體介面設計:
		-- 點開 Qt Designer => 畫圖 => 存檔為 "name".ui
		-- 於所儲存的資料夾上方輸入 cmd 呼叫終端機 
		-- 於終端機輸入 pyuic5 -x "name".ui -o "name".py


		--tts參考狀態機
		-- case tts_mode is
		-- 	when idle=>
		-- 		if pressed='1' and key=10 then
		-- 			tts_mode<=tts_play;
		-- 		end if;
		-- 	when tts_play=>
		-- 		tts_ena<='1';
		-- 		txt(0 to xx)<= name;
		-- 		if tts_done='1' then
		-- 			tts_ena <= '0';
		-- 			tts_mode<= stop;
		-- 		end if;
		-- 	when stop=>
		-- 		if tts_busy = '0' then
		-- 			tts_mode<= idle;
		-- 		end if;
		-- 	when others=>null;
		-- end case;
	end process;
end architecture;


-- d911101@g-mail.sivs.chc.edu.tw
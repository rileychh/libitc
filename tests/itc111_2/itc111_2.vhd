library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;

entity itc111_test2 is
	port (

		clk, rst_n : in std_logic;
		
		-- lcd
		lcd_sclk, lcd_mosi, lcd_ss_n, lcd_dc, lcd_bl, lcd_rst_n : out std_logic;

		-- sw
		sw : in u8r_t;

		-- seg
		seg_led, seg_com : out u8r_t;

		-- key
		key_row : in u4r_t;
		key_col : out u4r_t;

		--led
		rgb                 : out std_logic_vector(0 to 2);
	
		-- g r y
		led_g, led_r, led_y : out std_logic;

		--dot
		dot_red, dot_green, dot_com : out u8r_t;

		--buzzer
		buz : out std_logic;

		-- --uart
		uart_rx : in std_logic;  -- receive pin
		uart_tx : out std_logic; -- transmit pin
		dbg_b   : out u8r_t
	);
end itc111_test2;

architecture arch of itc111_test2 is

----------------------------------------------------------------------signal
	--user
		signal inter_rst : std_logic;
		signal keypad : character;
		
	--seg
		signal seg_data:string(1 to 8):=(others=>' ');
		signal seg_dot:u8r_t:=(others=>'0');
	--key
		signal pressed, pressed_i : std_logic;
		signal key : i4_t;
		
	--f(1khz)
		signal msec,load:i32_t;
		signal timer_ena:std_logic;
		
	--lcd_draw
		signal bg_color, text_color : l_px_t;
		signal addr : l_addr_t;
		signal text_size : integer range 1 to 12;
		signal data : string(1 to 12);
		signal font_start,font_busy,lcd_clear : std_logic;
		signal draw_done,draw_start : std_logic;
		signal x : integer range -5 to 159;
		signal y : integer range 0 to 159;
		
	--clk_1hz
		signal clk_1hz, time_clk : std_logic;
		signal clk_100hz, time_clk100 : std_logic;
	--mode
		type mode_t is (start,idle,value_add,change,loan,p2e);
		signal mode : mode_t;

	--currency
		type currency_t is (LIF,JOY,LOV);
		signal currency : currency_t;
		signal coco_LIF,coco_JOY,coco_LOV:i32_t;
	--8*8 dot led
		signal com_flag : std_logic;
		signal dot_x, dot_y : integer range 0 to 7;
		--green
		constant guy		: u8r_arr_t(0 to 7) := (x"00", x"00", x"80", x"C0", x"E0", x"C0", x"80", x"00");
		--red
		constant enemy		: u8r_arr_t(0 to 7) := (x"00", x"00", x"00", x"00", x"03", x"03", x"00", x"00");
		--user
		constant dot_clear : u8r_arr_t(0 to 7) := (x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00");
		constant dot_full : u8r_arr_t(0 to 7) := (x"ff", x"ff", x"ff", x"ff", x"ff", x"ff", x"ff", x"ff");
		signal data_g, data_r : u8r_arr_t(0 to 7);
	--uart
		signal tx_data, rx_data : u8_t := x"00";
		signal rx_start, rx_done : std_logic;
		signal tx_ena, tx_busy, rx_busy, rx_err : std_logic;

	--value_add
		signal add_count:i32_t;
		signal lcd_count : integer range 0 to 10;
		signal count : integer range 0 to 50;
		signal pass : u8_arr_t(0 to 3);
		signal pass_str : string(1 to 4);
		signal password : string(1 to 4);
		type add_t is (idle,lcd_show,in_pass,err,success,finish_add);
		signal add : add_t;

	--change
		type exchange_t is (idle,setup,number,confirm,show,stop);
		signal exchange : exchange_t;
		signal set_money : string(1 to 4);
		signal key_number : integer range 0 to 9999:=0;
		signal Q1000,Q100,Q10,Q1 : integer range 0 to 9999:=0;
		signal flag_currency : std_logic;
	--loan
		type loan_t is (idle,sub,show,stop);
		signal loan_mode : loan_t;
		signal money : integer range 0 to 5000:=0;
		signal interest : integer range 0 to 100:=0;

	--P2E
		type Play_to_earn_t is (idle,show,shoot,end_game);
		signal Play : Play_to_earn_t;
		signal end_flag,game_done : std_logic;
----------------------------------------------------------------------end signal

begin
--------------------------------------------begin packages
	clk_inst10 : entity work.clk(arch)
		generic map(
			freq => 1
		)
		port map(
			clk_in  => clk,
			rst_n   => rst_n,
			clk_out => clk_1hz
		);
	clk_inst100 : entity work.clk(arch)
		generic map(
			freq => 10
		)
		port map(
			clk_in  => clk,
			rst_n   => rst_n,
			clk_out => clk_100hz
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
			data_r    => data_g,
			data_g    => data_r
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
	key_inst : entity work.key(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			key_row => key_row,
			key_col => key_col,
			pressed => pressed_i,
			key     => key
		);

	timer_inst : entity work.timer(arch)
		port map(
			clk   => clk,
			rst_n => rst_n,		
			ena   => timer_ena,
			load  => load,
			msec  => msec
		);

	edge_inst_key : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => pressed_i,
			rising  => pressed,
			falling => open
		);

	edge_inst_lcd_done : entity work.edge(arch)
		port map
		(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => font_busy,
			rising  => draw_start,
			falling => draw_done
		);
	edge_inst_1hz : entity work.edge(arch)
		port map
		(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => clk_1hz,
			rising  => time_clk,		
			falling => open			
		);
	edge_inst_100hz : entity work.edge(arch)
		port map
		(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => clk_100hz,
			rising  => time_clk100,		
			falling => open			
		);
	edge_inst_uart : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => rx_busy,
			rising  => rx_start,
			falling => rx_done
		);
	edge_inst_end_flag : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => end_flag,
			rising  => game_done,
			falling => open
		);
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
	lcd_draw : entity work.gen_font(arch)
		port map(
			clk        => clk,
			rst_n      => rst_n,
			x          => x,			
			y          => y,			
			font_start => font_start,	
			font_busy  => font_busy,	
			text_size  => text_size,	
			data       => data,			
			text_color => text_color,	
			addr       => addr,			
			bg_color   => bg_color,		
			clear      => lcd_clear,	
			lcd_sclk   => lcd_sclk,		
			lcd_mosi   => lcd_mosi,		
			lcd_ss_n   => lcd_ss_n,		
			lcd_dc     => lcd_dc,
			lcd_bl     => lcd_bl,
			lcd_rst_n  => lcd_rst_n

		);

-------------------------------------------end packages
	inter_rst <= '0' when (key = 7) and (pressed = '1')else
				 '1';
	keypad <=
		'7' when (pressed = '1') and (key = 0) else
		'8' when (pressed = '1') and (key = 1) else
		'9' when (pressed = '1') and (key = 2) else
		'0' when (pressed = '1') and (key = 3) else
		'4' when (pressed = '1') and (key = 4) else
		'5' when (pressed = '1') and (key = 5) else
		'6' when (pressed = '1') and (key = 6) else
		'1' when (pressed = '1') and (key = 8) else
		'2' when (pressed = '1') and (key = 9) else
		'3' when (pressed = '1') and (key = 10) ;
	Process(clk,rst_n,inter_rst)
	begin
		if rst_n='0' or inter_rst='0' then
			com_flag	<='0';
			seg_data	<="        ";
			seg_dot		<=x"00";
			rgb			<="000";
			timer_ena	<='0';
			font_start	<='0';
			load		<= 0;
			mode		<= start;
			bg_color	<= white;
			lcd_clear	<= '1';
			money		<= 0;
			interest	<= 0;
			Play		<= idle;
			data_g		<= dot_clear;
			data_r		<= dot_clear;
			pass		<= (others => x"00");
			set_money	<= "    ";
			password	<= "    ";
			tx_ena		<= '0';
		elsif rising_edge(clk) then
			case mode is 
				when start=>
					timer_ena<='1';
					coco_LIF<=1000;
					coco_JOY<=1000;
					coco_LOV<=1000;
					mode<=idle;
					-- case msec is
					-- 	when 0 to 500=>
					-- 		buz<='1';
					-- 	when 501 to 1000=>
					-- 		buz<='0';
					-- 	when 1001 to 1500=>
					-- 		buz<='1';
					-- 	when 1501 to 2000=>
					-- 		buz<='0';
					-- 	when 2001 to 2500=>
					-- 		buz<='1';
					-- 	when 2501 to 3000=>
					-- 		buz<='0';
					-- 	when others=>
					-- 		timer_ena<='0';
					-- 		load<=0;
					-- 		mode<=idle;
					-- end case;
					
				when idle=>
					--clear before state flag
						timer_ena<='1';
						bg_color<=white;
						lcd_clear<='0';
						seg_data<="        ";
						seg_dot<=x"00";
						led_g<='1';
						led_r<='1';
						led_y<='1';
						data_g<=dot_clear;
						data_r<=dot_clear;

					if pressed='1' and key=14 then	--if change mode
						rgb<="000";
						case sw(0 to 3) is
							when "1000" =>--value_add
								rgb<="100";
								led_r<='1';
								led_g<='0';
								led_y<='0';
								dot_x<=0;
								dot_y<=0;
								com_flag<='0';
								timer_ena<='0';
								load<=0;
								font_start<='0';
								pass<=(others=> x"00");
								seg_data<="        ";
								seg_dot<=x"00";
								data_g<=dot_clear;
								data_r<=dot_full;
								lcd_clear<='1';
								lcd_count<=0;
								add<=idle;
								mode<=value_add;
							when "0100" =>--change
								rgb<="010";
								led_r<='0';
								led_g<='1';
								led_y<='0';
								dot_x<=0;
								dot_y<=0;
								timer_ena<='0';
								load<=0;
								com_flag<='0';
								mode<=change;
								seg_data<="        ";
								seg_dot<=x"00";
								data_g<=dot_full;
								data_r<=dot_clear;
								lcd_clear<='1';
								lcd_count<=0;
								exchange<=idle;--(idle,setup,confirm);
							when "0010" =>--loan
								rgb<="001";
								led_r<='0';
								led_g<='0';
								led_y<='1';
								dot_x<=0;
								dot_y<=0;
								com_flag<='0';
								seg_data<="        ";
								seg_dot<=x"00";
								data_g<=dot_clear;
								data_r<=dot_clear;
								lcd_clear<='1';
								lcd_count<=0;
								loan_mode<=idle;
								mode<=loan;
							when "0001" =>--p2e
								dot_x<=0;
								dot_y<=0;
								com_flag<='0';
								seg_data<="        ";
								seg_dot<=x"00";
								data_g<=dot_clear;
								data_r<=dot_clear;
								lcd_clear<='1';
								lcd_count<=0;
								mode<=p2e;
								Play<=idle;
							when others =>
								seg_data<="        ";
								seg_dot<=x"00";
								data_g<=dot_clear;
								data_r<=dot_clear;
								lcd_clear<='1';
								mode<=idle;
						end case;
					else
					----------------------------dot 掃描
						-- if com_flag='0' then	
						-- 	if time_clk100='1' then
						-- 		if dot_x=7 then
						-- 			dot_x<=0;
						-- 			com_flag<='1';
						-- 		else
						-- 			dot_x<=dot_x+1;
						-- 		end if;
						-- 	end if;
						-- 	data_r<=dot_clear;
						-- 	data_g(dot_x)(0)<='1';
						-- 	data_g(dot_x)(1)<='1';
						-- 	data_g(dot_x)(2)<='1';
						-- 	data_g(dot_x)(3)<='1';
						-- 	data_g(dot_x)(4)<='1';
						-- 	data_g(dot_x)(5)<='1';
						-- 	data_g(dot_x)(6)<='1';
						-- 	data_g(dot_x)(7)<='1';
						-- else
						-- 	if time_clk100='1' then
						-- 		if dot_y=7 then
						-- 			dot_y<=0;
						-- 			com_flag<='0';
						-- 		else
						-- 			dot_y<=dot_y+1;
						-- 		end if;
						-- 	end if;
						-- 	data_g<=dot_clear;
						-- 	data_r(0)(dot_y)<='1';
						-- 	data_r(1)(dot_y)<='1';
						-- 	data_r(2)(dot_y)<='1';
						-- 	data_r(3)(dot_y)<='1';
						-- 	data_r(4)(dot_y)<='1';
						-- 	data_r(5)(dot_y)<='1';
						-- 	data_r(6)(dot_y)<='1';
						-- 	data_r(7)(dot_y)<='1';
						-- end if;
					----------------------------show LED RGB
						case msec is  
							when 0 to 1000 =>--R
								rgb<="100";
							when 1001 to 2000 =>--G
								rgb<="010";
							when 2001 to 3000 =>--B
								rgb<="001";
							when others=>-- clear timer
								lcd_clear<='0';
								bg_color<=white;
								load<=0;
								timer_ena<='0';
						end case;
					----------------------------LCD
						case lcd_count is --show LCD
							when 0=>
								if y < y'high then
									if font_busy='0' then
										font_start<='1';
									end if;
									if draw_done='1' then 
										font_start<='0';
										y<=y+1;
									end if;
								else
									lcd_clear<='1';
									lcd_count<=1;
								end if;
							when 1=>
								y<=40;
								data<=" " & to_string((coco_LIF/1000),9,10,1) &"  "& to_string(((coco_LIF/100)-10*(coco_LIF/1000)),9,10,1) & "  " & to_string(((coco_LIF rem 100)-(coco_LIF rem 10))/10,9,10,1) &"  "& to_string((coco_LIF rem 10),9,10,1) &" ";
								font_start<='1';
								if draw_done='1' then
									font_start<='0';
									lcd_count<=2;
									y<=80;
								end if;
							when 2=>
								data<=" " & to_string((coco_JOY/1000),9,10,1) &"  "& to_string(((coco_JOY/100)-10*(coco_JOY/1000)),9,10,1) & "  " & to_string(((coco_JOY rem 100)-(coco_JOY rem 10))/10,9,10,1) &"  "& to_string((coco_JOY rem 10),9,10,1) &" ";
								font_start<='1';
								if draw_done='1' then
									font_start<='0';
									lcd_count<=3;
									y<=120;
								end if;
							when 3=>
								data<=" " & to_string((coco_LOV/1000),9,10,1) &"  "& to_string(((coco_LOV/100)-10*(coco_LOV/1000)),9,10,1) & "  " & to_string(((coco_LOV rem 100)-(coco_LOV rem 10))/10,9,10,1) &"  "& to_string((coco_LOV rem 10),9,10,1) &" ";
								font_start<='1';
								if draw_done='1' then
									font_start<='0';
									y<=0;
									lcd_count<=4;
								end if;
							-- when 4=>
								-- 	data<="            ";
								-- 	font_start<='1';
								-- 	if draw_done='1' then
								-- 		font_start<='0';
								-- 		lcd_count<=1;
								-- 	end if;
							when others=>
								lcd_count<=0;
						end case;

					end if;
				when value_add=>
					case add is
						when idle=>
							lcd_clear<='0';
							if pressed='1' and key=14 then
								case sw(0 to 3) is
									when "1000" =>
										currency<=LIF;
									when "1100" =>
										currency<=JOY;
									when "1110" =>
										currency<=LOV;
									when others=>null;
								end case;
								lcd_count<=0;
								add<=lcd_show;
							end if;
							case lcd_count is
								when 0 =>
									y<=40;
									case sw(0 to 3) is 
										when "1000"=>--LIF
											data<=" L  I  F    ";
										when "1100"=>--JOY
											data<=" J  O  Y    ";
										when "1110"=>--LOV
											data<=" L  O  V    ";
										when others=>--others
											data<="            ";
									end case;
									font_start<='1';
									if draw_done='1' then
										font_start<='0';
										lcd_count<=0;
									end if;
								when others=>
									lcd_count<=0;
							end case;
						when lcd_show=>
							lcd_clear<='0';
							if rx_done = '1' then    --接收軟體資料
								if to_integer(rx_data) = 13 then
									tx_ena <= '0';
									count <= 0;
									lcd_count<=0;
									add<=in_pass;
								else
									tx_ena <= '0';
									pass(count) <= rx_data;
									count <= count + 1;
								end if;
							end if;
							case lcd_count is
								when 0 =>
									y<=40;
									case currency is 
										when LIF=>
											data<=" L  I  F    ";
										when JOY=>
											data<=" J  O  Y    ";
										when LOV=>
											data<=" L  O  V    ";
										when others=>
											data<="            ";
									end case;
									font_start<='1';
									if draw_done='1' then
										font_start<='0';
										y<=80;
										lcd_count<=1;
									end if;
								when 1 =>
									data <="            ";
									font_start<='1';
									if draw_done='1' then
										font_start<='0';
										y<=0;
										lcd_count<=0;
									end if;
								when others=>null;
							end case;
						when in_pass=>
							if key<12 and key/=7 and pressed='1' then
								password<=password(2 to 4)&keypad;
							end if;
							case currency is 
								when LIF=>
									seg_data<=to_string(coco_LIF,9999,10,4)&password;
								when JOY=>
									seg_data<=to_string(coco_JOY,9999,10,4)&password;
								when LOV=>
									seg_data<=to_string(coco_LOV,9999,10,4)&password;
								when others=>
									data<="            ";
							end case;
							if pressed='1' and key=14 then
								if pass_str = password then--success
									tx_ena<='1';
									tx_data<=to_unsigned(1,8);
									add<=success;
									font_start<='0';
									lcd_clear<='0';
									lcd_count<=0;
								else--err
									tx_ena<='1';
									tx_data<=to_unsigned(0,8);
									add<=err;
									font_start<='0';
									lcd_clear<='1';
									lcd_count<=0;
								end if;
							end if;

							case lcd_count is
								when 0 =>
									y<=50;
									data <=" " & to_string(to_integer(pass(0))-48,9,10,1) & "  " & character'val(to_integer(pass(1))) & "  " & character'val(to_integer(pass(2))) & "  " & character'val(to_integer(pass(3)))& " ";
									pass_str<=data(2)&data(5)&data(8)&data(11);
									font_start<='1';
									if draw_done='1' then
										font_start<='0';
										y<=0;
										lcd_count<=0;
									end if;
								when others=>
									lcd_count<=0;
							end case;					
						when success=>
							if tx_busy='0' then
								tx_ena<='0';
							end if;
							-- Money add
								if time_clk='1' then
									case currency is 
										when LIF=>
											if coco_LIF>=9500 then
												coco_LIF<=9500;
												add<=finish_add;
											else
												coco_LIF<=coco_LIF+500;
											end if;
										when JOY=>
											if coco_JOY>=9500 then
												coco_JOY<=9500;
												add<=finish_add;
											else
												coco_JOY<=coco_JOY+500;
											end if;
										when LOV=>
											if coco_LOV>=9500 then
												coco_LOV<=9500;
												add<=finish_add;
											else
												coco_LOV<=coco_LOV+500;
											end if;
									end case;
								end if;
							--LCD Show
								case lcd_count is
									when 0=>
										y<=40;
										data<=" " & to_string((coco_LIF/1000),9,10,1) &"  "& to_string(((coco_LIF/100)-10*(coco_LIF/1000)),9,10,1) & "  " & to_string(((coco_LIF rem 100)-(coco_LIF rem 10))/10,9,10,1) &"  "& to_string((coco_LIF rem 10),9,10,1) &" ";
										font_start<='1';
										if draw_done='1' then
											font_start<='0';
											lcd_count<=1;
											y<=80;
										end if;
									when 1=>
										data<=" " & to_string((coco_JOY/1000),9,10,1) &"  "& to_string(((coco_JOY/100)-10*(coco_JOY/1000)),9,10,1) & "  " & to_string(((coco_JOY rem 100)-(coco_JOY rem 10))/10,9,10,1) &"  "& to_string((coco_JOY rem 10),9,10,1) &" ";
										font_start<='1';
										if draw_done='1' then
											font_start<='0';
											lcd_count<=2;
											y<=120;
										end if;
									when 2=>
										data<=" " & to_string((coco_LOV/1000),9,10,1) &"  "& to_string(((coco_LOV/100)-10*(coco_LOV/1000)),9,10,1) & "  " & to_string(((coco_LOV rem 100)-(coco_LOV rem 10))/10,9,10,1) &"  "& to_string((coco_LOV rem 10),9,10,1) &" ";
										font_start<='1';
										if draw_done='1' then
											font_start<='0';
											y<=40;
											lcd_count<=3;
										end if;
									-- when 3=>
										-- 	data<=" T  R  U  E ";
										-- 	font_start<='1';
										-- 	if draw_done='1' then
										-- 		font_start<='0';
										-- 		lcd_count<=0;
										-- 	end if;
									when others=>
										lcd_count<=0;
								end case;
							--Seg Show
								case currency is 
									when LIF=>
										seg_data<="    "&to_string(coco_LIF,9999,10,4);
									when JOY=>
										seg_data<="    "&to_string(coco_JOY,9999,10,4);
									when LOV=>
										seg_data<="    "&to_string(coco_LOV,9999,10,4);
									when others=>
										data<="            ";
								end case;
							
							--interrupt
								if pressed='1' and key=12 then
									password<="    ";
									seg_data<="        ";
									lcd_clear<='1';
									add<=idle;
									add_count<=0;
									mode<=idle;
								end if;

						when err=>
							---clear before mode
								if tx_busy='0' then
									tx_ena<='0';
								end if;
								password<="    ";
								seg_data<="        ";
								timer_ena<='1';
								add_count<=0;
							--bebe	
								if msec<=1000 then
									buz<='1';
									lcd_clear<='0';
								else
									timer_ena<='0';
									load<=0;
									buz<='0';
									lcd_clear<='1';
									mode<=idle;
								end if;
							--LCD Show
								case lcd_count is
									when 0=>
										y<=40;
										data<=" " & to_string((coco_LIF/1000),9,10,1) &"  "& to_string(((coco_LIF/100)-10*(coco_LIF/1000)),9,10,1) & "  " & to_string(((coco_LIF rem 100)-(coco_LIF rem 10))/10,9,10,1) &"  "& to_string((coco_LIF rem 10),9,10,1) &" ";
										font_start<='1';
										if draw_done='1' then
											font_start<='0';
											lcd_count<=1;
											y<=80;
										end if;
									when 1=>
										data<=" " & to_string((coco_JOY/1000),9,10,1) &"  "& to_string(((coco_JOY/100)-10*(coco_JOY/1000)),9,10,1) & "  " & to_string(((coco_JOY rem 100)-(coco_JOY rem 10))/10,9,10,1) &"  "& to_string((coco_JOY rem 10),9,10,1) &" ";
										font_start<='1';
										if draw_done='1' then
											font_start<='0';
											lcd_count<=2;
											y<=120;
										end if;
									when 2=>
										data<=" " & to_string((coco_LOV/1000),9,10,1) &"  "& to_string(((coco_LOV/100)-10*(coco_LOV/1000)),9,10,1) & "  " & to_string(((coco_LOV rem 100)-(coco_LOV rem 10))/10,9,10,1) &"  "& to_string((coco_LOV rem 10),9,10,1) &" ";
										font_start<='1';
										if draw_done='1' then
											font_start<='0';
											y<=0;
											lcd_count<=3;
										end if;
									-- when 3=>
										-- 	data<=" F  A  I  L ";
										-- 	font_start<='1';
										-- 	if draw_done='1' then
										-- 		font_start<='0';
										-- 		lcd_count<=0;
										-- 	end if;
									when others=>
										lcd_count<=0;
								end case;
						when finish_add=>
							password<="    ";
							seg_data<="        ";
							lcd_clear<='1';
							add_count<=0;
							mode<=idle;
						when others=>null;
					end case;
				when change=> 
					case exchange is 
						when idle=>
							lcd_clear<='1';
							font_start<='0';
							Q1<=0;
							Q10<=0;
							Q100<=0;
							Q1000<=0;
							set_money<="    ";
							key_number<=0;
							--choose coco
								if pressed='1' and key=14 then
									-- if flag_currency='1' then
										-- 	exchange<=stop;
										-- else
										-- 	exchange<=setup;
										-- end if;
									
									case sw(0 to 3) is
										when "1000" =>
											currency<=LIF;
										when "1100" =>
											currency<=JOY;
										when "1110" =>
											currency<=LOV;
										when others=>null;
									end case;
									exchange<=setup;
								end if;
							--seg show
								case sw(0 to 3) is
									when "1000"=>
										seg_data<="LIF "&to_string(coco_LIF,9999,10,4);
										-- flag_currency<='1';
									when "1100"=>
										seg_data<="JoY "&to_string(coco_JOY,9999,10,4);
										-- flag_currency<='0';
									when "1110"=>
										seg_data<="Lov "&to_string(coco_LOV,9999,10,4);
										-- flag_currency<='0';
									when others=>null;
								end case;
						when setup=>
							if key<12 and key/=7 and pressed='1' then
								set_money<=set_money(2 to 4)&keypad;
							end if;
							case currency is
								when LIF=>
									seg_data<=to_string(coco_LIF,9999,10,4)&set_money;
								when JOY=>
									seg_data<=to_string(coco_LIF,9999,10,4)&set_money;
								when LOV=>
									seg_data<=to_string(coco_LIF,9999,10,4)&set_money;
								when others=>null;
							end case;
							--to_integer(char)
								if key=14 and pressed='1' then
									exchange<=number;
									case set_money(1) is
										when '1' =>
											Q1000<=1000;
										when '2' =>
											Q1000<=2000;
										when '3' =>
											Q1000<=3000;
										when '4' =>
											Q1000<=4000;
										when '5' =>
											Q1000<=5000;
										when '6' =>
											Q1000<=6000;
										when '7' =>
											Q1000<=7000;
										when '8' =>
											Q1000<=8000;
										when '9' =>
											Q1000<=9000;
										when others=>
											Q1000<=0;
									end case;
									case set_money(2) is
										when '1' =>
											Q100<=100;
										when '2' =>
											Q100<=200;
										when '3' =>
											Q100<=300;
										when '4' =>
											Q100<=400;
										when '5' =>
											Q100<=500;
										when '6' =>
											Q100<=600;
										when '7' =>
											Q100<=700;
										when '8' =>
											Q100<=800;
										when '9' =>
											Q100<=900;
										when others=>
											Q100<=0;
									end case;
									case set_money(3) is
										when '1' =>
											Q10<=10;
										when '2' =>
											Q10<=20;
										when '3' =>
											Q10<=30;
										when '4' =>
											Q10<=40;
										when '5' =>
											Q10<=50;
										when '6' =>
											Q10<=60;
										when '7' =>
											Q10<=70;
										when '8' =>
											Q10<=80;
										when '9' =>
											Q10<=90;
										when others=>
											Q1000<=0;
									end case;
									case set_money(4) is
										when '1' =>
											Q1<=1;
										when '2' =>
											Q1<=2;
										when '3' =>
											Q1<=3;
										when '4' =>
											Q1<=4;
										when '5' =>
											Q1<=5;
										when '6' =>
											Q1<=6;
										when '7' =>
											Q1<=7;
										when '8' =>
											Q1<=8;
										when '9' =>
											Q1<=9;
										when others=>
											Q1000<=0;
									end case;
								end if;
						when number=>
							key_number<=Q1000+Q100+Q10+Q1;
							exchange<=confirm;
						when confirm=>--exchange rate
							if key_number<=coco_LIF then
								coco_LIF<=coco_LIF-key_number;
								case currency is
									when LIF=>null;
									when JOY=>
										coco_JOY<=coco_JOY+key_number*2+key_number/2;
										if coco_JOY>=9500 then
											coco_JOY<=9500;
										end if;
										lcd_count<=0;
										exchange<=show;
									when LOV=>
										coco_LOV<=coco_LOV+key_number*5;
										if coco_LOV>=9500 then
											coco_LOV<=9500;
										end if;
										lcd_count<=0;
										exchange<=show;
									when others=>null;
								end case;
							end if;
						when show=>
							lcd_clear<='0';
							set_money<="    ";
							------------------------seg
								-- case currency is
								-- 	when LIF=>
								-- 		seg_data<="Succ"&to_string(coco_LIF,9999,10,4);
								-- 	when JOY=>
								-- 		seg_data<="Succ"&to_string(coco_JOY,9999,10,4);
								-- 	when LOV=>
								-- 		seg_data<="Succ"&to_string(coco_LOV,9999,10,4);
								-- 	when others=>null;
								-- end case;
							case lcd_count is --LCD
								when 0=>
									y<=40;
									data<=" " & to_string((coco_LIF/1000),9,10,1) &"  "& to_string(((coco_LIF/100)-10*(coco_LIF/1000)),9,10,1) & "  " & to_string(((coco_LIF rem 100)-(coco_LIF rem 10))/10,9,10,1) &"  "& to_string((coco_LIF rem 10),9,10,1) &" ";
									font_start<='1';
									if draw_done='1' then
										font_start<='0';
										lcd_count<=1;
										y<=80;
									end if;
								when 1=>
									data<=" " & to_string((coco_JOY/1000),9,10,1) &"  "& to_string(((coco_JOY/100)-10*(coco_JOY/1000)),9,10,1) & "  " & to_string(((coco_JOY rem 100)-(coco_JOY rem 10))/10,9,10,1) &"  "& to_string((coco_JOY rem 10),9,10,1) &" ";
									font_start<='1';
									if draw_done='1' then
										font_start<='0';
										lcd_count<=2;
										y<=120;
									end if;
								when 2=>
									data<=" " & to_string((coco_LOV/1000),9,10,1) &"  "& to_string(((coco_LOV/100)-10*(coco_LOV/1000)),9,10,1) & "  " & to_string(((coco_LOV rem 100)-(coco_LOV rem 10))/10,9,10,1) &"  "& to_string((coco_LOV rem 10),9,10,1) &" ";
									font_start<='1';
									if draw_done='1' then
										font_start<='0';
										lcd_count<=0;
									end if;
								when others=>
									lcd_count<=0;
							end case;
							if pressed='1' and key=14 then
								mode<=idle;
							end if;
						when stop=>
							-- timer_ena<='1';
							-- if msec<=1000 then
							-- 	buz<='1';
							-- else
							-- 	buz<='0';
							-- 	timer_ena<='0';
							-- 	load<=0;
							-- 	mode<=idle;
							-- end if;
						when others=>null;
					end case;
					
				when loan=>
					lcd_clear<='0';
					case loan_mode is
						when idle=>
							if pressed='1' and key=14 then
								case sw(0 to 3) is
									when "1000" =>
										currency<=LIF;
									when "1100" =>
										currency<=JOY;
									when "1110" =>
										currency<=LOV;
									when others=>null;
								end case;
								lcd_count<=0;
								loan_mode<=show;
							end if;
							case lcd_count is
								when 0=>
									y<=40;
									case sw(0 to 3) is 
										when "1000"=>--LIF
											data<=" L  I  F    ";
										when "1100"=>--JOY
											data<=" J  O  Y    ";
										when "1110"=>--LOV
											data<=" L  O  V    ";
										when others=>
											data<="            ";
									end case;
									font_start<='1';
									if draw_done='1' then
										font_start<='0';
										y<=80;
										lcd_count<=1;
									end if;
								when others=>
									lcd_count<=0;
							end case;
						when show=>
							lcd_clear<='0';
							--add money
								if pressed='1' and key=15 then
									if money>=5000 then
										money<=5000;
										interest<=100;
									else
										money<=money+500;
									end if;
								end if;
							
							interest<=(money*2)/100;--operation
							seg_data<=to_string(money,5000,10,4) & to_string(interest,100,10,4);
							if pressed='1' and key=14 then
								loan_mode<=sub;
							end if;
							case lcd_count is
								when 0=>
									y<=40;
									case currency is 
										when LIF=>
											data<=" L  I  F    ";
										when JOY=>
											data<=" J  O  Y    ";
										when LOV=>
											data<=" L  O  V    ";
										when others=>
											data<="            ";
									end case;
									font_start<='1';
									if draw_done='1' then
										font_start<='0';
										y<=80;
										lcd_count<=1;
									end if;
								when 1=>
									case currency is 
										when LIF=>
											data<=" " & to_string((coco_LIF/1000),9,10,1) &"  "& to_string(((coco_LIF/100)-10*(coco_LIF/1000)),9,10,1) & "  " & to_string(((coco_LIF rem 100)-(coco_LIF rem 10))/10,9,10,1) &"  "& to_string((coco_LIF rem 10),9,10,1) &" ";
										when JOY=>
											data<=" " & to_string((coco_JOY/1000),9,10,1) &"  "& to_string(((coco_JOY/100)-10*(coco_JOY/1000)),9,10,1) & "  " & to_string(((coco_JOY rem 100)-(coco_JOY rem 10))/10,9,10,1) &"  "& to_string((coco_JOY rem 10),9,10,1) &" ";
										when LOV=>
											data<=" " & to_string((coco_LOV/1000),9,10,1) &"  "& to_string(((coco_LOV/100)-10*(coco_LOV/1000)),9,10,1) & "  " & to_string(((coco_LOV rem 100)-(coco_LOV rem 10))/10,9,10,1) &"  "& to_string((coco_LOV rem 10),9,10,1) &" ";
									end case;
									font_start<='1';
									if draw_done='1' then
										font_start<='0';
										y<=120;
										lcd_count<=2;
									end if;
								when 2=>
									data<=" "&to_string((interest/100),9,10,1)&"  "&to_string((interest rem 100)/10,9,10,1)&"  0    ";
									font_start<='1';
									if draw_done='1' then
										font_start<='0';
										y<=40;
										lcd_count<=0;
									end if;
								when others=>
									lcd_count<=0;
							end case;
						when sub=>
							case currency is 
								when LIF=>
									coco_LIF<=coco_LIF+money;
								when JOY=>
									coco_JOY<=coco_JOY+money;
								when LOV=>
									coco_LOV<=coco_LOV+money;
								when others=>null;
							end case;
							loan_mode<=stop;
						when stop=>
							mode<=idle;
							money<=0;
							interest<=0;
							seg_data<="        ";
							interest<=0;
							lcd_count<=0;
					end case;
				when p2e=>
					case Play is
						when idle=>
							if pressed='1' and key=14 then
								case sw(0 to 3) is
									when "1000" =>
										currency<=LIF;
									when "1100" =>
										currency<=JOY;
									when "1110" =>
										currency<=LOV;
									when others=>null;
								end case;
								Play<=show;
								data_g <= dot_clear;
								data_r <= dot_clear;
								timer_ena<='0';
								end_flag<='0';
								load<=0;
							end if;
							case sw(0 to 3) is
								when "1000"=>
									seg_data<="LIF "&to_string(coco_LIF,9999,10,4);
								when "1100"=>
									seg_data<="JoY "&to_string(coco_JOY,9999,10,4);
								when "1110"=>
									seg_data<="Lov "&to_string(coco_LOV,9999,10,4);
								when others=>null;
							end case;
							
						when show=>
							data_g <= guy;
							data_r <= enemy;
							if pressed='1' and key=5 then
								Play<=shoot;
							end if;
						when shoot=>
							--bullet
								timer_ena<='1';
								if msec<1000 then--shoot 1
									data_g(4)(3) <= '1';
									data_r(4)(3) <= '1';
								elsif msec<=2000 then--shoot 2
									data_g(4)(3) <= '0';
									data_r(4)(3) <= '0';
									data_g(4)(5) <= '1';
									data_r(4)(5) <= '1';
								elsif msec<=2500 then--clear enemy
									end_flag<='1';
									data_g <= guy;
									data_r <= dot_clear;
									timer_ena<='0';
									load<=0;
								end if;
							--add money
								if game_done='1' then
									case currency is
										when LIF=>
											coco_LIF<=coco_LIF+100;
										when JOY=>
											coco_JOY<=coco_JOY+100;
										when LOV=>
											coco_LOV<=coco_LOV+100;
										when others=>null;
									end case;
									Play<=end_game;
								end if;
						when end_game=>
							--show seg
								case currency is
									when LIF=>
										seg_data<="LIF "&to_string(coco_LIF,9999,10,4);
									when JOY=>
										seg_data<="JoY "&to_string(coco_JOY,9999,10,4);
									when LOV=>
										seg_data<="Lov "&to_string(coco_LOV,9999,10,4);
									when others=>null;
								end case;
							--back idle
								if pressed='1' and key= 14 then 
									mode<=idle;
									data_g<=dot_clear;
									data_r<=dot_clear;
								end if;
						when others=>null;
					end case;
				when others=>null;
			end case;
		end if;
	end process;
end architecture;
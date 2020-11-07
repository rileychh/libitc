library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity bruh is
	port (
		-- sys
		clk, rst_n : in std_logic; -- rising edge clock, low reset
		-- sw
		sw : in byte_t;
		-- seg
		seg_1, seg_2, seg_s : out byte_be_t; -- abcdefgp * 2, seg2_s1 ~ seg1_s4
		-- key
		key_row : in nibble_be_t;
		key_col : out nibble_be_t;
		-- dht
		dht_data : inout std_logic;
		-- tsl
		tsl_scl, tsl_sda : inout std_logic;
		-- tts
		tts_scl, tts_sda : inout std_logic
	);
end bruh;

architecture arch of bruh is

	signal sw_i : byte_t;
	signal seg : string(1 to 8);
	signal pressed : std_logic;
	signal key : integer range 0 to 15;
	signal temp, hum : integer range 0 to 99;

	signal mode : integer range 0 to 3;
	constant key_start_stop : integer := 0;
	constant key_rst : integer := 1;
	constant key_func : integer := 2;
	constant key_up : integer := 3;
	constant key_down : integer := 4;
	constant key_ok : integer := 5;

begin

	sw_inst : entity work.sw(arch)
		port map(
			clk    => clk,
			rst_n  => rst_n,
			sw     => sw,
			sw_out => sw_i
		);

	seg_inst : entity work.seg(arch)
		port map(
			clk   => clk,
			rst_n => rst_n,
			seg_1 => seg_1,
			seg_2 => seg_2,
			seg_s => seg_s,
			data  => seg,
			dot => (others => '0')
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

	dht_inst : entity work.dht(arch)
		port map(
			clk      => clk,
			rst_n    => rst_n,
			dht_data => dht_data,
			temp_int => temp,
			temp_dec => open,
			hum_int  => hum,
			hum_dec  => open
		);

	mode <= to_integer(sw(7 downto 6));

	process (all) begin
		if rising_edge(pressed) then
			key_pressed <= key;
		end if;
	end process;

	process (clk, rst_n) begin
		if rst_n = '0' then
			state <= idle;
		elsif rising_edge(clk) then
			case state is
				when idle =>
					if pressed = '1' and key = then

					end if;
			end case;
		end if;
	end process;

end arch;

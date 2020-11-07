library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.bruh_data.all;

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
  signal seg_dot : byte_t;
  signal pressed : std_logic;
  signal key : integer range 0 to 15;
  signal temp, hum : integer range 0 to 99;
  signal lux : integer range 0 to 40000;
  signal tts_ena, tts_busy : std_logic;
  signal txt : bytes_t(0 to txt_len_max - 1);
  signal txt_len : integer range 0 to txt_len_max;

  signal mode : integer range 0 to 3;
  constant key_start_stop : integer := 0;
  constant key_rst : integer := 1;
  constant key_func : integer := 2;
  constant key_up : integer := 6;
  constant key_down : integer := 7;
  constant key_ok : integer := 8;

  type state_t is (idle, run, pause);
  signal state : state_t;

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
      dot   => seg_dot
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

  tsl_inst : entity work.tsl(arch)
    port map(
      tsl_scl => tsl_scl,
      tsl_sda => tsl_sda,
      clk     => clk,
      rst_n   => rst_n,
      lux     => lux
    );

  tts_inst : entity work.tts(arch)
    generic map(
      txt_len_max => txt_len_max
    )
    port map(
      tts_scl => tts_scl,
      tts_sda => tts_sda,
      clk     => clk,
      rst_n   => rst_n,
      ena     => tts_ena,
      busy    => tts_busy,
      txt     => txt,
      txt_len => txt_len
    );

  process (clk, rst_n)
    -- tts_test vars	
    variable func : integer range 0 to 3;
    variable param : string(1 to 5); -- parameter of function displayed on seg
    variable vol_disp : integer range 0 to 9; -- func 1 param: volume
    variable vol : integer range 0 to 9; -- func 1 param: volume
    variable content_disp : std_logic; -- func 2 param disp: saves info output_content after pressing key_ok
    variable content : std_logic; -- func 2 param: text (low) or music (high)
    variable channel_disp : integer range 0 to 2; -- func 3 param disp: saves info output_content after pressing key_ok
    variable channel : integer range 0 to 2; -- func 3 param: {0: right, 1: left, 2: both}
    variable tts_config : bytes_t(0 to 3);
  begin
    if rst_n = '0' then
      state <= idle;
    elsif rising_edge(clk) then
      case state is
        when idle =>
          if pressed = '1' and key = key_start_stop then
            mode <= to_integer(sw(7 downto 6));
          end if;

        when run =>
          if pressed = '1' and key = key_start_stop then
            state <= pause;
          end if;

          case mode is
            when 0 => -- lcd_test
            when 1 => -- tts_test
              tts_ena <= '0';

              if pressed = '1' then
                case key is
                  when key_rst =>
                    func := 1;
                    vol := 5;
                  when key_func =>
                    if func = 3 then -- loop between functions
                      func := 1;
                    else
                      func := func + 1;
                    end if;
                  when others => null;
                end case;
              end if;

              case func is
                when 1 => -- vol
                  if pressed = '1' then
                    case key is
                      when key_up =>
                        vol := vol + 1;
                      when key_down =>
                        vol := vol - 1;
                      when key_ok =>
                        vol := vol_disp;
                      when others => null;
                    end case;
                  end if;

                  seg <= "F1 VOL" & to_string(vol_disp, vol_disp'high, 10, 2);
                  seg_dot <= "00100000";

                when 2 => -- speak & music
                  if pressed = '1' then
                    case key is
                      when key_down =>
                        content_disp := not content_disp;
                      when key_ok =>
                        content := content_disp;
                      when others => null;
                    end case;
                  end if;

                  seg(1 to 3) <= "F2 ";
                  if content_disp = '0' then -- text
                    seg(4 to 8) <= "SPEAt";
                  else -- music
                    seg(4 to 8) <= "3US1C";
                  end if;
                  seg_dot <= "00100001";

                when 3 => -- output channel
                  if pressed = '1' then
                    case key is
                      when key_down =>
                        if channel_disp = 2 then
                          channel_disp := 0;
                        else
                          channel_disp := channel_disp + 1;
                        end if;
                      when key_ok =>
                        channel := channel_disp;
                      when others => null;
                    end case;
                  end if;

                  seg(1 to 3) <= "F3 ";
                  case channel_disp is
                    when 0 => -- right
                      seg(4 to 8) <= "A16H7";
                    when 1 => -- left
                      seg(4 to 8) <= "LEF7 ";
                    when 2 => -- both
                      seg(4 to 8) <= "807H ";
                  end case;
                  seg_dot <= "00100001";

                when others => null;
              end case;

              tts_config(0 to 2) := (tts_set_vol, to_unsigned((2 ** 8 / 10) * vol, 8), tts_set_channel);
              case channel_disp is
                when 0 => -- right
                  tts_config(3) := x"06";
                when 1 => -- left
                  tts_config(3) := x"05";
                when 2 => -- both
                  tts_config(3) := x"07";
              end case;

              if content = '0' then -- text
                txt(0 to 45 + 4) <= tts_config & txt_sensor_init;
                txt_len <= 46 + 4;
              else -- music
                txt(0 to 4 + 4) <= tts_config & tts_play_file & x"00" & x"01" & x"00" & x"01"; -- play 0001.wav 1 time
                txt_len <= 5 + 4;
              end if;
              tts_ena <= '1';

            when 2 => -- sensors_test
            when 3 => -- combined_test
          end case;

        when pause =>
          if pressed = '1' and key = key_start_stop then
            state <= run;
          end if;

      end case;
    end if;
  end process;

end arch;

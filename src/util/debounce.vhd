--------------------------------------------------------------------------------
--
--   FileName:         debounce.vhd
--   Dependencies:     none
--   Design Software:  Quartus Prime Version 17.0.0 Build 595 SJ Lite Edition
--
--   HDL CODE IS PROVIDED "AS IS."  DIGI-KEY EXPRESSLY DISCLAIMS ANY
--   WARRANTY OF ANY KIND, WHETHER EXPRESS OR IMPLIED, INCLUDING BUT NOT
--   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
--   PARTICULAR PURPOSE, OR NON-INFRINGEMENT. IN NO EVENT SHALL DIGI-KEY
--   BE LIABLE FOR ANY INCIDENTAL, SPECIAL, INDIRECT OR CONSEQUENTIAL
--   DAMAGES, LOST PROFITS OR LOST DATA, HARM TO YOUR EQUIPMENT, COST OF
--   PROCUREMENT OF SUBSTITUTE GOODS, TECHNOLOGY OR SERVICES, ANY CLAIMS
--   BY THIRD PARTIES (INCLUDING BUT NOT LIMITED TO ANY DEFENSE THEREOF),
--   ANY CLAIMS FOR INDEMNITY OR CONTRIBUTION, OR OTHER SIMILAR COSTS.
--
--   Version History
--   Version 2.0 6/28/2019 Scott Larson
--     Added asynchronous active-low reset
--     Made stable time higher resolution and simpler to specify
--   Version 1.0 3/26/2012 Scott Larson
--     Initial Public Release
--
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity debounce_eewiki is
  generic (
    clk_freq    : integer := 50_000_000; --system clock frequency in Hz
    stable_time : integer := 10);        --time button must remain stable in ms
  port (
    clk     : in std_logic;   --input clock
    reset_n : in std_logic;   --asynchronous active low reset
    button  : in std_logic;   --input signal to be debounced
    result  : out std_logic); --debounced signal
end debounce_eewiki;

architecture logic of debounce_eewiki is
  signal flipflops : std_logic_vector(1 downto 0); --input flip flops
  signal counter_set : std_logic; --sync reset to zero
begin

  counter_set <= flipflops(0) xor flipflops(1); --determine when to start/reset counter

  process (clk, reset_n)
    variable count : integer range 0 to clk_freq * stable_time/1000; --counter for timing
  begin
    if (reset_n = '0') then --reset
      flipflops(1 downto 0) <= "00"; --clear input flipflops
      result <= '0'; --clear result register
    elsif (rising_edge(clk)) then --rising clock edge
      flipflops(0) <= button; --store button value in 1st flipflop
      flipflops(1) <= flipflops(0); --store 1st flipflop value in 2nd flipflop
      if (counter_set = '1') then --reset counter because input is changing
        count := 0; --clear the counter
      elsif (count < clk_freq * stable_time/1000) then --stable input time is not yet met
        count := count + 1; --increment counter
      else --stable input time is met
        result <= flipflops(1); --output the stable value
      end if;
    end if;
  end process;

end logic;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.tts_p.all;

entity tts_test is
	port (
		-- sys
		clk, rst : in std_logic;
		-- sw
		sw : in unsigned(7 downto 0);
		-- tts
		tts_scl, tts_sda : inout std_logic
	);
end tts_test;

architecture arch of tts_test is

	-- "王正宏不會寫VHDL", 16
	constant txt_sentence_1 : txt_t(0 to 15) := (
	x"a4", x"fd", x"a5", x"bf", x"a7", x"bb", x"a4", x"a3",
	x"b7", x"7c", x"bc", x"67", x"56", x"48", x"44", x"4c");

	-- "但是，他會寫PHP", 15
	constant txt_sentence_2 : txt_t(0 to 14) := (
	x"a6", x"fd", x"ac", x"4f", x"a1", x"41", x"a5", x"4c", 
	x"b7", x"7c", x"bc", x"67", x"50", x"48", x"50"
	);

	signal tts_ena : std_logic;
	signal tts_busy : std_logic;
	signal tts_txt : txt_t(0 to 15);
	signal tts_txt_len : integer range 0 to 16;
	
begin

	tts_inst: entity work.tts(arch)
	generic map (
		txt_len_max => 16
	)
	port map (
		tts_scl => tts_scl,
		tts_sda => tts_sda,
		clk => clk,
		rst => rst,
		ena => tts_ena,
		busy => tts_busy,
		txt => tts_txt,
		txt_len => tts_txt_len
	);

	process (clk) begin
		if rising_edge(clk) then
			tts_txt <= txt_sentence_1; -- "王正宏不會寫VHDL"
			tts_txt_len <= 16;
			tts_ena <= '1';
		end if;
	end process;
	
end arch;
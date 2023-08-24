library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library altera_mf;
use altera_mf.altera_mf_components.all;

entity image is
	port (
		clk  : in std_logic := '1';
		addr : in unsigned(14 downto 0);
		data : out unsigned(23 downto 0)
	);
end image;

architecture arch of image is

	signal data_i : std_logic_vector(23 downto 0);

begin

	data <= unsigned(data_i);

	altsyncram_component : altsyncram
	generic map(
		address_aclr_a         => "NONE",
		clock_enable_input_a   => "BYPASS",
		clock_enable_output_a  => "BYPASS",
		init_file              => "./tests/lcd/ip/image.mif",
		intended_device_family => "Cyclone III",
		lpm_hint               => "ENABLE_RUNTIME_MOD=NO",
		lpm_type               => "altsyncram",
		numwords_a             => 20480,
		operation_mode         => "ROM",
		outdata_aclr_a         => "NONE",
		outdata_reg_a          => "UNREGISTERED",
		widthad_a              => 15,
		width_a                => 24,
		width_byteena_a        => 1
	)
	port map(
		clock0    => clk,
		address_a => std_logic_vector(addr),
		q_a       => data_i
	);

end arch;

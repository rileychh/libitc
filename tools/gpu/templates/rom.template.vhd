<%
from math import ceil, log2
def width(n):
		return int(ceil(log2(n)))
addr_width = width(mif_depth)
%>\
library ieee;
use ieee.std_logic_1164.all;

library altera_mf;
use altera_mf.altera_mf_components.all;

entity ${name} is
	port (
		clk  : in std_logic := '1';
		addr : in unsigned(${addr_width - 1} downto 0);
		data : out unsigned(${mif_width - 1} downto 0)
	);
end ${name};

architecture arch of ${name} is

	signal addr_i : std_logic_vector(${addr_width - 1} downto 0);
	signal data_i : std_logic_vector(${mif_width - 1} downto 0);

begin

	addr <= unsigned(addr_i);
	data <= unsigned(data_i);

	altsyncram_component : altsyncram
	generic map(
		address_aclr_a         => "NONE",
		clock_enable_input_a   => "BYPASS",
		clock_enable_output_a  => "BYPASS",
		init_file              => "./${mif_path}",<%doc>relative to libitc.qpf</%doc>
		intended_device_family => "Cyclone III",
		lpm_hint               => "ENABLE_RUNTIME_MOD=NO",
		lpm_type               => "altsyncram",
		numwords_a             => ${mif_depth},
		operation_mode         => "ROM",
		outdata_aclr_a         => "NONE",
		outdata_reg_a          => "UNREGISTERED",
		widthad_a              => ${addr_width},
		width_a                => ${mif_width},
		width_byteena_a        => 1
	)
	port map(
		clock0    => clk,
		address_a => addr_i,
		q_a       => data_i
	);

end arch;

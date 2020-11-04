--////////////////////////// FIFO RAM MEMORY ///////////////////////////////////--
-- ***********************************************************************
-- FileName: FIFO.vhd
-- FPGA: Lattice ECP2-70E
-- IDE: Lattice Diamond ver 2.0.1
--
-- HDL IS PROVIDED "AS IS." DIGI-KEY EXPRESSLY DISCLAIMS ANY
-- WARRANTY OF ANY KIND, WHETHER EXPRESS OR IMPLIED, INCLUDING BUT NOT
-- LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
-- PARTICULAR PURPOSE, OR NON-INFRINGEMENT. IN NO EVENT SHALL DIGI-KEY
-- BE LIABLE FOR ANY INCIDENTAL, SPECIAL, INDIRECT OR CONSEQUENTIAL
-- DAMAGES, LOST PROFITS OR LOST DATA, HARM TO YOUR EQUIPMENT, COST OF
-- PROCUREMENT OF SUBSTITUTE GOODS, TECHNOLOGY OR SERVICES, ANY CLAIMS
-- BY THIRD PARTIES (INCLUDING BUT NOT LIMITED TO ANY DEFENSE THEREOF),
-- ANY CLAIMS FOR INDEMNITY OR CONTRIBUTION, OR OTHER SIMILAR COSTS.
-- DIGI-KEY ALSO DISCLAIMS ANY LIABILITY FOR PATENT OR COPYRIGHT
-- INFRINGEMENT.
--
-- Version History
-- Version 1.0 15/11/2012 Tony Storey
-- Initial Public Release
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
------------------------------------------------------

----------------------------------------------------------------------------
entity fifo_eewiki is
	generic (
		addr_w  : integer := 4;  -- address width in bits
		data_w  : integer := 24; -- data width in bits
		buff_l  : integer := 16; -- buffer length must be less than address space as in  buff_l <or= 2^(addr_w)-1
		almst_f : integer := 3;  -- fifo flag for almost full regs away from empty fifo
		almst_e : integer := 3   -- fifo regs away from empty fifo
	);
	port (
		clk         : in std_logic;
		n_reset     : in std_logic;
		rd_en       : in std_logic; -- read enable 
		wr_en       : in std_logic; -- write enable 
		data_in     : in std_logic_vector(DATA_W - 1 downto 0);
		data_out    : out std_logic_vector(DATA_W - 1 downto 0);
		data_count  : out std_logic_vector(ADDR_W downto 0);
		empty       : out std_logic;
		full        : out std_logic;
		almst_empty : out std_logic;
		almst_full  : out std_logic;
		err         : out std_logic
	);
end fifo_eewiki;
----------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------------------
architecture arch of fifo_eewiki is

	type reg_file_type is array (0 to ((2 ** ADDR_W) - 1)) of std_logic_vector(DATA_W - 1 downto 0);

	-----memory, pointers, and flip flops-------
	signal mem_array : reg_file_type;
	signal rd_ptr, wr_ptr : std_logic_vector(ADDR_W - 1 downto 0); -- current pointers
	signal rd_ptr_nxt : std_logic_vector(ADDR_W - 1 downto 0); -- next pointer
	signal wr_ptr_nxt : std_logic_vector(ADDR_W - 1 downto 0); -- next pointer
	signal full_ff, empty_ff : std_logic; -- full and empty flag flip flops
	signal full_ff_nxt : std_logic; -- full and empty flag flip flops for next state
	signal empty_ff_nxt : std_logic;
	signal almst_f_ff : std_logic; -- watermark flip flops for almost full/empty flags
	signal almst_e_ff : std_logic;
	signal almst_f_ff_nxt : std_logic; -- watermark flip flops for almost full/empty flags for next state
	signal almst_e_ff_nxt : std_logic;
	signal q_reg, q_next : std_logic_vector(ADDR_W downto 0); -- data counter
	signal q_add, q_sub : std_logic;

	---------------------------------------------------

begin

	---------- Process to update read, write, full, and empty on clock edges
	reg_update :
	process (clk)
	begin
		if rising_edge(clk) then
			if (n_reset = '0') then
				rd_ptr <= (others => '0');
				wr_ptr <= (others => '0');
				full_ff <= '0';
				empty_ff <= '1';
				almst_f_ff <= '0';
				almst_e_ff <= '1';
				q_reg <= (others => '0');
			else
				rd_ptr <= rd_ptr_nxt;
				wr_ptr <= wr_ptr_nxt;
				full_ff <= full_ff_nxt;
				empty_ff <= empty_ff_nxt;
				almst_f_ff <= almst_f_ff_nxt;
				almst_e_ff <= almst_e_ff_nxt;
				q_reg <= q_next;
			end if; -- end of n_reset if
		end if; -- end of rising_edge(clk) if
	end process;

	-- --------------Process to control almost full and almost emptly flags
	Wtr_Mrk_Cont :
	process (q_reg, almst_e_ff, almst_f_ff)
	begin
		almst_e_ff_nxt <= almst_e_ff;
		almst_f_ff_nxt <= almst_f_ff;
		--check to see if wr_ptr is ALMST_E away from rd_ptr (aka almost empty)
		if (conv_integer(q_reg) < (ALMST_E)) then
			almst_e_ff_nxt <= '1';
		else
			almst_e_ff_nxt <= '0';
		end if;
		if (conv_integer(q_reg) > (BUFF_L - 1 - ALMST_F)) then
			almst_f_ff_nxt <= '1';
		else
			almst_f_ff_nxt <= '0';
		end if;
	end process;
	----------- Process to control read and write pointers and empty/full flip flops
	Ptr_Cont :
	process (wr_en, rd_en, wr_ptr, rd_ptr, empty_ff, full_ff, q_reg)

	begin
		wr_ptr_nxt <= wr_ptr; -- no change to pointers
		rd_ptr_nxt <= rd_ptr;
		full_ff_nxt <= full_ff;
		empty_ff_nxt <= empty_ff;
		q_add <= '0';
		q_sub <= '0';

		---------- check if fifo is full during a write attempt, after a write increment counter
		----------------------------------------------------
		if (wr_en = '1' and rd_en = '0') then
			if (full_ff = '0') then
				if (conv_integer(wr_ptr) < BUFF_L - 1) then
					q_add <= '1';
					wr_ptr_nxt <= wr_ptr + '1';
					empty_ff_nxt <= '0';
				else
					wr_ptr_nxt <= (others => '0');
					empty_ff_nxt <= '0';
				end if;
				-- check if fifo is full
				if (conv_integer(wr_ptr + '1') = conv_integer(rd_ptr) or (conv_integer(wr_ptr) = (BUFF_L - 1) and conv_integer(rd_ptr) = 0)) then
					full_ff_nxt <= '1';
				end if;
			end if;
		end if;
		---------- check to see if fifo is empty during a read attempt, after a read decrement counter
		---------------------------------------------------------------
		if (wr_en = '0' and rd_en = '1') then
			if (empty_ff = '0') then
				if (conv_integer(rd_ptr) < BUFF_L - 1) then
					if (conv_integer(q_reg) > 0) then
						q_sub <= '1';
					else
						q_sub <= '0';
					end if;
					rd_ptr_nxt <= rd_ptr + '1';
					full_ff_nxt <= '0';
				else
					rd_ptr_nxt <= (others => '0');
					full_ff_nxt <= '0';
				end if;
				-- check if fifo is empty
				if (conv_integer(rd_ptr + '1') = conv_integer(wr_ptr) or (conv_integer(rd_ptr) = (BUFF_L - 1) and conv_integer(wr_ptr) = 0)) then
					empty_ff_nxt <= '1';
				end if;
			end if;
		end if;
		-----------------------------------------------------------------
		if (wr_en = '1' and rd_en = '1') then
			if (conv_integer(wr_ptr) < BUFF_L - 1) then
				wr_ptr_nxt <= wr_ptr + '1';
			else
				wr_ptr_nxt <= (others => '0');
			end if;
			if (conv_integer(rd_ptr) < BUFF_L - 1) then
				rd_ptr_nxt <= rd_ptr + '1';
			else
				rd_ptr_nxt <= (others => '0');
			end if;
		end if;
	end process;
	-------- Process to control memory array writing and reading		
	mem_cont :
	process (clk)
	begin
		if rising_edge(clk) then
			if (n_reset = '0') then
				mem_array <= (others => (others => '0')); -- reset memory array
				err <= '0';
			else
				-- if write enable and not full then latch in data and increment wright pointer
				if (wr_en = '1') and (full_ff = '0') then
					mem_array (conv_integer(wr_ptr)) <= data_in;
					err <= '0';
				elsif (wr_en = '1') and (full_ff = '1') then -- check if full and trying to write
					err <= '1';
				end if;
				-- if read enable and fifo not empty then latch data out and increment read pointer
				if (rd_en = '1') and (empty_ff = '0') then
					data_out <= mem_array (conv_integer(rd_ptr));
					err <= '0';
				elsif (rd_en = '1') and (empty_ff = '1') then -- check if empty and trying to read 
					err <= '1';
				end if;
			end if; -- end of n_reset if
		end if; -- end of rising_edge(clk) if
	end process;

	-------- counter to keep track of almost full and almost empty 
	q_next <= q_reg + 1 when q_add = '1' else
		q_reg - 1 when q_sub = '1' else
		q_reg;

	-------- connect ff to output ports
	full <= full_ff;
	empty <= empty_ff;
	almst_empty <= almst_e_ff;
	almst_full <= almst_f_ff;
	data_count <= q_reg;

end arch;
---------------------------------------------------------------------------------------
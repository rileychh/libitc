library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package itc is
	--------------------------------------------------------------------------------
	-- common types
	--------------------------------------------------------------------------------

	subtype u2_t is unsigned(1 downto 0);
	subtype u2r_t is unsigned(0 to 1); -- big endian bits
	type u2_arr_t is array (integer range <>) of u2_t;
	type u2r_arr_t is array (integer range <>) of u2r_t;

	subtype u4_t is unsigned(3 downto 0);
	subtype u4r_t is unsigned(0 to 3); -- big endian nibble
	type u4_arr_t is array (integer range <>) of u4_t;
	type u4r_arr_t is array (integer range <>) of u4r_t;

	subtype u8_t is unsigned(7 downto 0);
	subtype u8r_t is unsigned(0 to 7); -- big endian byte
	type u8_arr_t is array (integer range <>) of u8_t;
	type u8r_arr_t is array (integer range <>) of u8r_t;

	subtype u16_t is unsigned(15 downto 0);
	subtype u16r_t is unsigned(0 to 15); -- big endian word
	type u16_arr_t is array (integer range <>) of u16_t;
	type u16r_arr_t is array (integer range <>) of u16r_t;

	subtype i4_t is integer range 0 to 2 ** 4 - 1;
	type i4_arr_t is array (integer range <>) of i4_t;

	subtype i8_t is integer range 0 to 2 ** 8 - 1;
	type i8_arr_t is array (integer range <>) of i8_t;

	subtype i16_t is integer range 0 to 2 ** 16 - 1;
	type i16_arr_t is array (integer range <>) of i16_t;

	subtype i32_t is integer range 0 to integer'high;
	type i32_arr_t is array (integer range <>) of i32_t;

	--------------------------------------------------------------------------------
	-- system constants
	--------------------------------------------------------------------------------

	constant sys_clk_freq : integer := 50_000_000;

	--------------------------------------------------------------------------------
	-- seg glyph constants
	--------------------------------------------------------------------------------

	constant seg_deg : character := character'val(0);

	--------------------------------------------------------------------------------
	-- tts command constants
	--------------------------------------------------------------------------------

	-- constant tts_instant_clear : u8_t := (x"80"); -- DO NOT USE, MAY CRASH MODULE
	constant tts_instant_vol_up : u8_t := x"81";
	constant tts_instant_vol_down : u8_t := x"82";
	constant tts_instant_pause : u8_arr_t(0 to 1) := (x"8f", x"00");
	constant tts_instant_resume : u8_arr_t(0 to 1) := (x"8f", x"01");
	constant tts_instant_skip : u8_arr_t(0 to 1) := (x"8f", x"02"); -- skips delay or music
	constant tts_instant_soft_reset : u8_arr_t(0 to 1) := (x"8f", x"03"); -- TODO what's the use case?

	-- concatenate 1 speed byte after
	-- e.g. 0x83 0x19 means 25% faster 
	-- range 0x00 to 0x28 (40%)
	-- default is 0x00
	constant tts_set_speed : u8_t := x"83";

	-- concatenate 1 volume byte after
	-- e.g. 0xff means 0db, 0xfe means -0.5db, 0x01 means -127db, 0x00 means mute
	-- range 0x00 to 0xff
	-- default is 0xd2 (-105db)
	constant tts_set_vol : u8_t := x"86";

	-- concatenate 4 time bytes after
	-- e.g. 0x0001d4c0 means delay 120000ms
	-- range 0x00000000 to 0xffffffff
	constant tts_delay : u8_t := x"87";

	-- concatenate 2 filename bytes and 2 repeat bytes after
	-- e.g. 0x03fd_0005 means play "1021.wav" 5 times
	-- filename can be 0x0001 to 0x270f (0001 to 9999)
	-- repeat = 0 means do not stop
	constant tts_play_file : u8_t := x"88";

	constant tts_sleep : u8_t := x"89";

	-- concatenate 1 state byte after, only last 3 bits (2 downto 0) have an effect
	-- e.g. 0x06 means set MO2, MO1, MO0 = 1, 1, 0
	-- range 0x00 to 0x07
	-- default is 0x07
	constant tts_set_mo : u8_t := x"8a";

	-- concatenate 1 mode byte after
	-- | mode  | line out | headphone | speaker |
	-- | :---: | :------: | :-------: | :-----: |
	-- | 0x01  |          |           |    L    |
	-- | 0x02  |          |           |    R    |
	-- | 0x03  |          |           |  both   |
	-- | 0x04  |          |   both    |         |
	-- | 0x05  |          |     L     |    L    |
	-- | 0x06  |          |     R     |    R    |
	-- | 0x07  |          |   both    |  both   |
	-- | 0x08  |   both   |           |         |
	-- | 0x09  |    L     |           |    L    |
	-- | 0x0a  |    R     |           |    R    |
	-- | 0x0b  |   both   |           |  both   |
	constant tts_set_channel : u8_t := x"8b";

	--------------------------------------------------------------------------------
	-- common functions
	--------------------------------------------------------------------------------

	-- to_integer: converts '0' and '1' to 0 and 1.
	-- logic: signal to be converted
	function to_integer(logic : std_logic) return integer;

	-- log. Yes, log. returns ceil(log_base(num))
	function log(base, num : integer) return integer;

	-- repeat: repeat same bit/vector many times.
	-- logic/vector: std_logic/vector to repeat
	-- num: number of times to repeat
	function repeat(logic : std_logic; num : integer) return std_logic_vector;
	function repeat(logic : std_logic; num : integer) return unsigned;
	function repeat(vector : std_logic_vector; num : integer) return std_logic_vector;
	function repeat(vector : unsigned; num : integer) return unsigned;

	-- reverse: returns vector in reversed order.
	-- vector: vector to be reversed
	function reverse(vector : std_logic_vector) return std_logic_vector;
	function reverse(vector : unsigned) return unsigned;

	-- reduce: and/or/xor all bits in a std_logic_vector
	-- vector: vector to be reduced, index range must include 0
	-- operation: can be "and", "or_", "xor". not "or" because VHDL need fixed-length strings
	function reduce(vector : std_logic_vector; operation : string) return std_logic;
	function reduce(vector : unsigned; operation : string) return std_logic;

	-- index_of: searches vector for the element, and returns its index
	-- vector: vector to be searched
	-- element: element to look for
	function index_of(vector : std_logic_vector; element : std_logic) return integer;
	function index_of(vector : unsigned; element : std_logic) return integer;

	-- to_string: convert num into decimal string
	-- num: the unsigned number to be converted
	-- base: output base system. can be 2/8/10/16.
	function to_string(num, num_max, base, length : integer) return string;
	function to_string(num, num_max, base, length : integer) return u8_arr_t;
end package;

package body itc is
	function to_integer(logic : std_logic) return integer is begin
		if logic = '0' then
			return 0;
		else
			return 1;
		end if;
	end function;

	function log(base, num : integer) return integer is
		variable temp : integer := 1;
		variable result : integer := 0;
	begin
		for i in 0 to num loop
			if temp < num then
				temp := temp * base;
				result := result + 1;
			else
				return result;
			end if;
		end loop;
	end function;

	function repeat(logic : std_logic; num : integer) return std_logic_vector is
		variable result : std_logic_vector(0 to num - 1);
	begin
		for i in result'range loop
			result(i) := logic;
		end loop;

		return result;
	end function;

	function repeat(logic : std_logic; num : integer) return unsigned is
		variable result : unsigned(0 to num - 1);
	begin
		for i in result'range loop
			result(i) := logic;
		end loop;

		return result;
	end function;

	function repeat(vector : std_logic_vector; num : integer) return std_logic_vector is
		variable result : std_logic_vector(0 to vector'length * num - 1);
		variable vector_asc : std_logic_vector(0 to vector'length - 1);
	begin
		if vector'ascending then
			vector_asc := vector;
		else
			vector_asc := reverse(vector);
		end if;

		for i in 0 to num - 1 loop
			result(i * vector_asc'length to i * vector_asc'length + vector_asc'high) := vector_asc;
		end loop;

		if vector'ascending then
			return result;
		else
			return reverse(result);
		end if;
	end function;

	function repeat(vector : unsigned; num : integer) return unsigned is begin
		return unsigned(repeat(std_logic_vector(vector), num));
	end function;

	function reverse(vector : std_logic_vector) return std_logic_vector is
		variable result : std_logic_vector(vector'reverse_range);
	begin
		for i in vector'range loop
			result(i) := vector(i);
		end loop;

		return result;
	end function;

	function reverse(vector : unsigned) return unsigned is begin
		return unsigned(reverse(std_logic_vector(vector)));
	end function;

	function reduce(vector : std_logic_vector; operation : string) return std_logic is
		variable result : std_logic := vector(0);
	begin
		for i in vector'range loop
			case operation is
				when "and" =>
					result := result and vector(i);
				when "or_" =>
					result := result or vector(i);
				when "xor" =>
					result := result xor vector(i);
				when others =>
					return 'X';
			end case;
		end loop;

		return result;
	end function;

	function reduce(vector : unsigned; operation : string) return std_logic is begin
		return reduce(std_logic_vector(vector), operation);
	end function;

	function index_of(vector : std_logic_vector; element : std_logic) return integer is
		variable temp : std_logic_vector(vector'range);
	begin
		for i in vector'range loop
			if vector(i) = element then
				return i;
			end if;
		end loop;

		return 0;
	end function;

	function index_of(vector : unsigned; element : std_logic) return integer is begin
		return index_of(std_logic_vector(vector), element);
	end function;

	function to_bcd(num, num_max, dec_width : integer) return unsigned is
		constant bin_width : integer := log(2, num_max);
		variable bin : unsigned(bin_width - 1 downto 0) := to_unsigned(num, bin_width);
		variable bcd : unsigned(dec_width * 4 - 1 downto 0) := (others => '0');
	begin
		-- https://en.wikipedia.org/wiki/Double_dabble 
		for i in 0 to bin_width - 1 loop
			-- check if any nibble (bcd digit) is more then 4
			for digit in 0 to dec_width - 1 loop
				if bcd(digit * 4 + 3 downto digit * 4) > 4 then
					bcd(digit * 4 + 3 downto digit * 4) := bcd(digit * 4 + 3 downto digit * 4) + 3; -- add 3 to the digit
				end if;
			end loop;

			--   shift
			--  <------
			-- bcd & bin
			bcd := bcd sll 1;
			bcd(bcd'right) := bin(bin'left);
			bin := bin sll 1;
		end loop;

		return bcd;
	end function;

	function to_string(num, num_max, base, length : integer) return string is
		variable temp : unsigned(3 downto 0);
		variable result : string(1 to length);
	begin
		for c in 0 to length - 1 loop
			case base is
				when 2 =>
					temp := "000" & to_unsigned(num, length)(c);
				when 8 =>
					temp := "0" & to_unsigned(num, length * 3)(c * 3 + 2 downto c * 3);
				when 10 =>
					temp := to_bcd(num, num_max, length)(c * 4 + 3 downto c * 4); -- convert BCD to string
				when 16 =>
					temp := to_unsigned(num, length * 4)(c * 4 + 3 downto c * 4);
				when others =>
					return (1 to length => 'E');
			end case;

			if temp < 10 then -- 0 to 9
				result(length - c) := character'val(to_integer(temp) + character'pos('0'));
			else -- A to F
				result(length - c) := character'val(to_integer(temp) - 10 + character'pos('A'));
			end if;
		end loop;

		return result;
	end function;

	function to_string(num, num_max, base, length : integer) return u8_arr_t is
		constant str : string := to_string(num, num_max, base, length);
		variable result : u8_arr_t(0 to length - 1);
	begin
		for char in str'range loop
			result(char - 1) := to_unsigned(character'pos(str(char)), 8);
		end loop;

		return result;
	end function;
end package body;

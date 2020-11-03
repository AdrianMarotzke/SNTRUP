library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.constants.all;

-- Stack memory
entity stack_memory is
	Generic(
		DEPTH : integer := 8
	);
	port(
		clock        : in  std_logic;
		reset        : in  std_logic;
		push_stack   : in  std_logic;
		pop_stack    : in  std_logic;
		stack_input  : in  integer range 0 to 2**p_num_bits;
		stack_output : out integer range 0 to 2**p_num_bits
	);
end entity stack_memory;

architecture RTL of stack_memory is

	type stack_memory_type is array (DEPTH downto 0) of integer range 0 to 2**p_num_bits;
	signal stack_memory : stack_memory_type;

	signal stack_pointer : integer range 0 to DEPTH;
begin

	stack_mem : process(clock, reset) is
	begin
		if reset = '1' then
			stack_pointer <= 0;
		--stack_output <= 0;
		elsif rising_edge(clock) then
			if push_stack = '1' and pop_stack = '0' and stack_pointer /= DEPTH then
				stack_memory(stack_pointer + 1) <= stack_input;
				stack_pointer                   <= stack_pointer + 1;
			end if;

			if pop_stack = '1' and push_stack = '0' and stack_pointer /= 0 then
				--stack_memory  <= 0 & stack_memory(DEPTH downto 1);
				stack_pointer <= stack_pointer - 1;
			end if;
		end if;
	end process stack_mem;
	stack_output <= stack_memory(stack_pointer);

end architecture RTL;

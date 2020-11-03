library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Compares two numbers with another, and outputs the min and max
entity comparator is
	generic(
		WIDTH : natural := 32
	);
	port(
		a   : in  unsigned(WIDTH-1 downto 0);
		b   : in  unsigned(WIDTH-1 downto 0);
		min : out unsigned(WIDTH-1 downto 0);
		max : out unsigned(WIDTH-1 downto 0)
	);
end entity comparator;

architecture RTL of comparator is

begin
	min <= a when a < b else b;
	max <= b when a < b else a;
end architecture RTL;

--architecture RTL_2 of comparator is
--	signal ab_xor : unsigned(WIDTH-1 downto 0);
--	signal c : unsigned(WIDTH-1 downto 0);
--	signal c2 : unsigned(WIDTH-1 downto 0);
--	signal c3 : unsigned(WIDTH-1 downto 0);
--	signal c4 : unsigned(WIDTH-1 downto 0);
--	
--begin
--	ab_xor <= a xor b;
--	c <= b-a;
--	c2 <= c xor (ab_xor and(c xor b));
--	c3 <= to_unsigned(0, WIDTH)-shift_right(c2, WIDTH-1);
--	c4 <= c3 and ab_xor;
--	
--	min <= a xor c4;
--	max <= b xor c4;
--end architecture RTL_2;
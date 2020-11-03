library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.constants.all;

-- calculates the element in Zq mod 3, output is in Z3. Out put has latency of 2 clock cycles
entity mod3_freeze is
	port(
		clock  : in  std_logic;
		reset  : in  std_logic;
		input  : in  signed(q_num_bits - 1 downto 0);
		enable : in std_logic;
		output : out signed(1 downto 0);
		output_rounded : out signed(q_num_bits -1 downto 0);
		output_valid: out std_logic
	);
end entity mod3_freeze;

architecture RTL of mod3_freeze is
	constant k : integer := 16; --integer(ceil(log2(real(q))));

	constant r : integer := integer(floor(real(2**k) / real(3)));

	constant size_of_r : integer := integer(ceil(log2(real(r))));
    
	signal temp_1        : signed(q_num_bits + size_of_r + 1 downto 0);
	signal out_1         : signed(q_num_bits + size_of_r + 4 downto 0);

	signal input_delayed : signed(q_num_bits - 1 downto 0);
    signal input_shifted : signed(q_num_bits downto 0);
    
   signal input_rounded        : signed(q_num_bits + size_of_r + 4 downto 0);
   
	signal fma_temp : signed(q_num_bits + size_of_r + 4 downto 0);
	
	signal pipe1 : std_logic;
	signal pipe2 : std_logic;
begin

    input_shifted <= input + to_signed(q12, 14);   
	temp_1        <= shift_right((to_signed(r, size_of_r + 1) * input_shifted+2**(k-1)), k) when rising_edge(clock) and enable = '1';
	input_delayed <= input when rising_edge(clock) and enable = '1';

    input_rounded <= to_signed(3, 3) * temp_1 - q12;
	fma_temp <= signed(input_delayed) - input_rounded;

	out_1 <= fma_temp when rising_edge(clock);

    output <= out_1(1 downto 0);
    output_rounded <= input_rounded(q_num_bits -1 downto 0) when rising_edge(clock);
    
	pipe_proc : process(clock, reset) is
	begin
		if reset = '1' then
			pipe1 <= '0';
			pipe2 <= '0';
		elsif rising_edge(clock) then
			pipe1 <= enable;
			pipe2 <= pipe1;
		end if;
	end process pipe_proc;
	
	output_valid <= pipe2;
end architecture RTL;

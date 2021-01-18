library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.constants.all;


-- calculates the function (data_in_a*f_zero- data_in_b*g_zero) mod q
entity modq_minus_product is
	port(
		clock         : in  std_logic;
		reset         : in  std_logic;
		data_in_a     : in  std_logic_vector(q_num_bits - 1 downto 0);
		data_in_b     : in  std_logic_vector(q_num_bits - 1 downto 0);
		f_zero        : in  std_logic_vector(q_num_bits - 1 downto 0);
		g_zero        : in  std_logic_vector(q_num_bits - 1 downto 0);
		output_freeze : out signed(q_num_bits - 1 downto 0)
	);
end entity modq_minus_product;

architecture RTL of modq_minus_product is
	signal minus_multiplication : signed(q_num_bits * 2 - 1 downto 0);

	signal ref_mult_a : signed(q_num_bits * 2 - 1 downto 0);
	signal ref_mult_b : signed(q_num_bits * 2 - 1 downto 0);

	signal data_in_a_sign : signed(q_num_bits - 1 downto 0);
	signal data_in_b_sign : signed(q_num_bits - 1 downto 0);
	signal f_zero_sign    : signed(q_num_bits - 1 downto 0);
	signal g_zero_sign    : signed(q_num_bits - 1 downto 0);

begin
	data_in_a_sign <= signed(data_in_a);
	data_in_b_sign <= signed(data_in_b);
	f_zero_sign    <= signed(f_zero);
	g_zero_sign    <= signed(g_zero);

	ref_mult_a <= f_zero_sign * data_in_a_sign when rising_edge(clock);
	ref_mult_b <= g_zero_sign * data_in_b_sign when rising_edge(clock);

	minus_multiplication <= ref_mult_a - ref_mult_b when rising_edge(clock); 

	modq_freeze_inst : entity work.modq_freeze(RTL)
		port map(
			clock  => clock,
			reset  => reset,
			input  => minus_multiplication(q_num_bits * 2 - 1 downto 0),
			output => output_freeze
		);
end architecture RTL;

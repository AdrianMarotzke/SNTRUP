library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.constants.all;

-- calculates the element in intervall [-q*q/4 ; q*q/4] mod q, output is in Zq.
entity modq_freeze is
	port(
		clock  : in  std_logic;
		reset  : in  std_logic;
		input  : in  signed(q_num_bits * 2 - 1 downto 0);
		output : out signed(q_num_bits - 1 downto 0)
	);
end entity modq_freeze;

architecture RTL of modq_freeze is
	constant k : integer := integer(ceil(log2(real(q))));

	constant r : integer := integer(floor(real(4**k) / real(q)));

	signal temp_1        : signed(q_num_bits * 3 + 1 downto 0);
	signal out_1         : signed(q_num_bits * 4 + 2 downto 0);
	signal out_2         : signed(q_num_bits * 4 + 2 downto 0);
	signal out_3         : signed(q_num_bits * 4 + 2 downto 0);
	signal input_delayed : signed(q_num_bits * 2 - 1 downto 0);

	signal fma_temp : signed(q_num_bits * 4 + 2 downto 0);
begin
	temp_1        <= shift_right((to_signed(r, q_num_bits + 2) * input), k * 2) when rising_edge(clock);
	input_delayed <= input when rising_edge(clock);

	fma_temp <= signed(input_delayed) - to_signed(q, q_num_bits + 1) * temp_1; -- TODO maybe add extra reg here

	out_1 <= fma_temp when rising_edge(clock);
	out_2 <= fma_temp - q when rising_edge(clock);
	out_3 <= fma_temp - 2 * q when rising_edge(clock);

	output <= out_1(q_num_bits - 1 downto 0) when out_1 < q_half
		else out_2(q_num_bits - 1 downto 0) when out_1 >= q_half and out_1 < q + q_half
		else out_3(q_num_bits - 1 downto 0);
end architecture RTL;
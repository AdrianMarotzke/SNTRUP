library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.constants.all;

-- Multiplies the input rq polynomail with 3, then reduces mod q.
-- Latency is 3 clock cycles
entity rq_mult3 is
	port(
		clock        : in  std_logic;
		reset        : in  std_logic;
		enable       : in  std_logic;
		input        : in  std_logic_vector(q_num_bits - 1 downto 0);
		output       : out std_logic_vector(q_num_bits - 1 downto 0);
		output_valid : out std_logic
	);
end entity rq_mult3;

architecture RTL of rq_mult3 is
	signal input_mult_3 : signed(q_num_bits * 2 - 1 downto 0);

	signal output_signed : signed(q_num_bits - 1 downto 0);

	signal input_mult_3_minus_q : signed(q_num_bits * 2 - 1 downto 0);
	signal input_mult_3_plus_q  : signed(q_num_bits * 2 - 1 downto 0);
	signal input_mult_3_zero    : signed(q_num_bits * 2 - 1 downto 0);

	signal pipe1 : std_logic;
	signal pipe2 : std_logic;
	signal pipe3 : std_logic;

begin
	input_mult_3 <= signed(input) * to_signed(3, q_num_bits) when rising_edge(clock) and enable = '1';

	pipe_proc : process(clock, reset) is
	begin
		if reset = '1' then
			pipe1 <= '0';
			pipe2 <= '0';
			pipe3 <= '0';
		elsif rising_edge(clock) then
			pipe1 <= enable;
			pipe2 <= pipe1;
			pipe3 <= pipe2;
		end if;
	end process pipe_proc;

	output_valid <= pipe3;

	input_mult_3_minus_q <= input_mult_3 - q when rising_edge(clock);
	input_mult_3_plus_q  <= input_mult_3 + q when rising_edge(clock);
	input_mult_3_zero    <= input_mult_3 when rising_edge(clock);

	output_signed <= input_mult_3_plus_q(q_num_bits - 1 downto 0) when input_mult_3_zero < -q12
	                 else input_mult_3_minus_q(q_num_bits - 1 downto 0) when input_mult_3_zero > q12
	                 else input_mult_3_zero(q_num_bits - 1 downto 0);

	output <= std_logic_vector(output_signed) when rising_edge(clock);
end architecture RTL;

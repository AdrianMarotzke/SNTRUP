library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.constants.all;

-- Divides a 32 bit number by indexed constant. Constants are defines in constants.pkg.vhd
entity division_32_by_const is
	port(
		clock         : in  std_logic;
		reset         : in  std_logic;
		dividend      : in  STD_LOGIC_VECTOR(31 downto 0);
		divisor_index : in  STD_LOGIC_VECTOR(6 downto 0);
		quotient      : out STD_LOGIC_VECTOR(31 downto 0);
		remainder     : out STD_LOGIC_VECTOR(15 downto 0)
	);
end entity division_32_by_const;

architecture RTL of division_32_by_const is

	constant pipe_len : integer := 4;

	type type_index_array is array (pipe_len downto 0) of std_logic_vector(6 downto 0);
	signal index_pipe : type_index_array;

	type type_mul_result is array (pipe_len downto 0) of unsigned(32 + max_divdend_width downto 0);
	signal mul_result : type_mul_result;

	type type_dividend_array is array (pipe_len downto 0) of unsigned(31 downto 0);
	signal dividend_pipe : type_dividend_array;

	signal quotient_reg  : unsigned(31 downto 0);
	signal remainder_reg : unsigned(32 + max_divdend_width - 1 downto 0);

	--signal mul_result_var_sig : unsigned(32 + max_divdend_width downto 0);

	constant test : decode_divisior_type := inv_m;

	signal dividend_in      : STD_LOGIC_VECTOR(31 downto 0);
	signal divisor_index_in : STD_LOGIC_VECTOR(6 downto 0);

	signal mul_result_var : unsigned(31 downto 0);
begin

	divide_process : process(clock) is
	begin
		if rising_edge(clock) then
			if reset = '1' then
				dividend_in      <= (others => '0');
				divisor_index_in <= (others => '0');
				dividend_pipe    <= (others => (others => '0'));
				index_pipe       <= (others => (others => '0'));
				mul_result       <= (others => (others => '0'));
				mul_result_var   <= (others => '0');
				remainder_reg    <= (others => '0');
				quotient_reg     <= (others => '0');
			else
				dividend_in      <= dividend;
				divisor_index_in <= divisor_index;

				dividend_pipe(0) <= unsigned(dividend_in);
				index_pipe(0)    <= divisor_index_in;

				mul_result(0) <= unsigned(dividend_in) * inv_m(to_integer(unsigned(divisor_index_in)));
				--mul_result(1)      <= mul_result_var(32 + decode_div_shift + radix_width_array(to_integer(unsigned(divisor_index_in))) - 1 downto decode_div_shift + radix_width_array(to_integer(unsigned(divisor_index_in))));
				--mul_result_var_sig <= mul_result_var;

				dividend_pipe(pipe_len downto 1) <= dividend_pipe(pipe_len - 1 downto 0);
				mul_result(pipe_len downto 1)    <= mul_result(pipe_len - 1 downto 0);
				index_pipe(pipe_len downto 1)    <= index_pipe(pipe_len - 1 downto 0);

				mul_result_var <= mul_result(pipe_len - 1)(32 + decode_div_shift + radix_width_array(to_integer(unsigned(index_pipe(pipe_len - 1)))) - 1 downto decode_div_shift + radix_width_array(to_integer(unsigned(index_pipe(pipe_len - 1)))));
				remainder_reg  <= dividend_pipe(pipe_len) - mul_result_var * to_unsigned(M_array(to_integer(unsigned(index_pipe(pipe_len)))), max_divdend_width);
				quotient_reg   <= mul_result_var;
			end if;
		end if;
	end process divide_process;

	remainder <= std_logic_vector(remainder_reg(15 downto 0));
	quotient  <= std_logic_vector(quotient_reg);
end architecture RTL;

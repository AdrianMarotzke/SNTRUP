library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.constants.all;
use work.data_type.all;

-- Contains the division and modulo entities, and the pipeline registers
entity div_mod_pipeline is
	port(
		clock                    : in  std_logic;
		reset                    : in  std_logic;
		dividend                 : in  std_logic_vector(31 downto 0);
		divisor_index            : in  std_logic_vector(6 downto 0);
		divisor_index_mod        : in  std_logic_vector(6 downto 0);
		decode_command_pipe_in   : in  std_logic;
		bram_R2_address_pipe_in  : in  std_logic_vector(p_num_bits - 1 downto 0);
		store_cmd_pipe_in        : in  divmod_cmd;
		decode_command_pipe_out  : out std_logic;
		bram_R2_address_pipe_out : out std_logic_vector(p_num_bits - 1 downto 0);
		store_cmd_pipe_out       : out divmod_cmd;
		remainder_mod            : out std_logic_vector(15 downto 0);
		remainder_pipe_delay_out : out std_logic_vector(15 downto 0)
	);
end entity div_mod_pipeline;

architecture RTL of div_mod_pipeline is

	signal dividend_in      : std_logic_vector(31 downto 0);

	signal divisor_index_in : std_logic_vector(6 downto 0);
	signal divisor_index_mod_in : std_logic_vector(6 downto 0);

	signal quotient      : std_logic_vector(31 downto 0);
	signal remainder_div : std_logic_vector(15 downto 0);

	signal interleaved_modulo : std_logic;

	signal decode_command_pipe_delay : std_logic_vector(14 downto 0);

	type address_delay is array (14 downto 0) of std_logic_vector(p_num_bits - 1 downto 0);
	signal bram_R2_address_pipe_delay : address_delay;

	type reg_index_delay is array (7 downto 0) of std_logic_vector(6 downto 0);
	signal reg_index_pipe_delay : reg_index_delay;

	type divmod_cmd_array is array (14 downto 0) of divmod_cmd;
	signal store_cmd_pipe_delay : divmod_cmd_array;

	type quotient_delay is array (7 downto 0) of std_logic_vector(15 downto 0);
	signal remainder_pipe_delay : quotient_delay;

begin

	decode_command_pipe_delay(0) <= decode_command_pipe_in;
	decode_command_pipe_out      <= decode_command_pipe_delay(14);

	bram_R2_address_pipe_delay(0) <= bram_R2_address_pipe_in;
	bram_R2_address_pipe_out      <= bram_R2_address_pipe_delay(14);

	store_cmd_pipe_delay(0) <= store_cmd_pipe_in;
	store_cmd_pipe_out      <= store_cmd_pipe_delay(14);
	
	reg_index_pipe_delay(0) <= divisor_index_mod;
	divisor_index_mod_in <= reg_index_pipe_delay(7);

	bram_R2_address_pipe_delay(0) <= bram_R2_address_pipe_in;
	bram_R2_address_pipe_out      <= bram_R2_address_pipe_delay(14);

	remainder_pipe_delay(0)  <= remainder_div;
	remainder_pipe_delay_out <= remainder_pipe_delay(7);

	bram_pipe_shift_reg : process(clock) is
	begin
		if rising_edge(clock) then
			if reset = '1' then
				decode_command_pipe_delay(14 downto 1) <= (others => '0');
			else
				decode_command_pipe_delay(14 downto 1)  <= decode_command_pipe_delay(13 downto 0);
				bram_R2_address_pipe_delay(14 downto 1) <= bram_R2_address_pipe_delay(13 downto 0);
				store_cmd_pipe_delay(14 downto 1)       <= store_cmd_pipe_delay(13 downto 0);
				remainder_pipe_delay(7 downto 1)       <= remainder_pipe_delay(6 downto 0);
				
				reg_index_pipe_delay(7 downto 1)       <= reg_index_pipe_delay(6 downto 0);
			end if;
		end if;
	end process bram_pipe_shift_reg;

	interleaved_modulo <= decode_command_pipe_delay(7);

	dividend_in      <= dividend when interleaved_modulo = '0' else quotient;
	divisor_index_in <= divisor_index when interleaved_modulo = '0' else divisor_index_mod_in;

	remainder_mod <= remainder_div;

	division_32_by_const_inst : entity work.division_32_by_const
		port map(
			clock         => clock,
			reset         => reset,
			dividend      => dividend_in,
			divisor_index => divisor_index_in,
			quotient      => quotient,
			remainder     => remainder_div
		);

end architecture RTL;

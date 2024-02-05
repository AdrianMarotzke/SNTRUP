library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.constants.all;

-- Generate a short (t-small) element. This is done by generating p 32 bit random numbers, with 2*t odd, and p-2*t even.
-- These are then sorted, and then only the lower 2 bits are used. The sorting is in constant time in regard to data.
entity small_random_weights is
	port(
		clock               : in  std_logic;
		reset               : in  std_logic;
		start               : in  std_logic;
		small_weights_valid : out std_logic;
		small_weights_out   : out signed(1 downto 0);
		done                : out std_logic;
		random_enable       : out std_logic;
		random_output		: in std_logic_vector(31 downto 0)
	);
end entity small_random_weights;

architecture RTL of small_random_weights is

	type state_type is (reset_state, init_state, generating_elements, pre_sort, sorting, rounding, done_state);
	signal state_weight            : state_type := reset_state;

	signal random_output_even : std_logic_vector(31 downto 0);
	signal random_output_odd  : std_logic_vector(31 downto 0);

	signal generate_counter : integer range 0 to p := 0;
	signal rounding_counter : integer range 0 to p := 0;

	signal bram_write_enable_a_fsm : std_logic;

	signal bram_address_a      : std_logic_vector(p_num_bits - 1 downto 0);
	signal bram_write_enable_a : std_logic;
	signal bram_data_in_a      : std_logic_vector(31 downto 0);
	signal bram_data_out_a     : std_logic_vector(31 downto 0);

	signal bram_address_b      : std_logic_vector(p_num_bits - 1 downto 0);
	signal bram_write_enable_b : std_logic;
	signal bram_data_in_b      : std_logic_vector(31 downto 0);
	signal bram_data_out_b     : std_logic_vector(31 downto 0);

	signal bram_address_a_sort      : std_logic_vector(p_num_bits - 1 downto 0);
	signal bram_write_enable_a_sort : std_logic;
	signal bram_data_in_a_sort      : std_logic_vector(31 downto 0);
	signal bram_data_out_a_sort     : std_logic_vector(31 downto 0);

	signal bram_address_b_sort    : std_logic_vector(p_num_bits - 1 downto 0);
	signal bram_write_enable_sort : std_logic;
	signal bram_data_in_b_sort    : std_logic_vector(31 downto 0);
	signal bram_data_out_b_sort   : std_logic_vector(31 downto 0);

	signal sorting_done  : std_logic;
	signal sorting_start : std_logic;

	signal small_weights : signed(31 downto 0);

begin
	fsm_process : process(clock, reset) is
	begin
		if reset = '1' then
			state_weight                   <= reset_state;
			generate_counter        <= 0;
			rounding_counter        <= 0;
			random_enable           <= '0';
			bram_write_enable_a_fsm <= '0';
			sorting_start           <= '0';
			small_weights_valid     <= '0';
			done                    <= '0';
		elsif rising_edge(clock) then
			case state_weight is
				when reset_state =>
					state_weight <= init_state;
				when init_state =>
					if start = '1' then
						state_weight <= generating_elements;
					else
						state_weight <= init_state;
					end if;
					random_enable           <= '0';
					generate_counter        <= 0;
					rounding_counter        <= 0;
					bram_write_enable_a_fsm <= '0';
					small_weights_valid     <= '0';
					done                    <= '0';
				when generating_elements =>
					if generate_counter = p - 1 then
						state_weight <= pre_sort;
					else
						state_weight <= generating_elements;
					end if;

					bram_write_enable_a_fsm <= '1';
					random_enable           <= '1';
					generate_counter        <= generate_counter + 1;
				when pre_sort =>
					state_weight                   <= sorting;
					bram_write_enable_a_fsm <= '0';
					random_enable           <= '0';
				when sorting =>
					if sorting_done = '1' then
						state_weight            <= rounding;
						sorting_start    <= '0';
						rounding_counter <= 0;
					else
						state_weight         <= sorting;
						sorting_start <= '1';

					end if;
				when rounding =>
					if rounding_counter = p - 1 then
						state_weight <= done_state;
					else
						state_weight <= rounding;
					end if;
					small_weights_valid <= '1';
					rounding_counter    <= rounding_counter + 1;
				when done_state =>
					small_weights_valid <= '0';
					state_weight               <= init_state;
					sorting_start       <= '0';
					done                <= '1';
			end case;
		end if;
	end process fsm_process;

	block_ram_inst : entity work.block_ram
		generic map(
			ADDRESS_WIDTH => p_num_bits,
			DATA_WIDTH    => 32
		)
		port map(
			clock      => clock,
			address_a  => bram_address_a,
			write_a    => bram_write_enable_a,
			data_in_a  => bram_data_in_a,
			data_out_a => bram_data_out_a,
			address_b  => bram_address_b,
			write_b    => bram_write_enable_b,
			data_in_b  => bram_data_in_b,
			data_out_b => bram_data_out_b
		);

	-- When state is sorting, use addresse from sorting module, when rounding, use address from rounding counter
	bram_address_a <= bram_address_a_sort when state_weight = sorting
		else std_logic_vector(to_unsigned(rounding_counter, p_num_bits)) when state_weight = rounding
		else std_logic_vector(to_signed(generate_counter - 1, p_num_bits + 1)(p_num_bits - 1 downto 0));

	-- when counter <= t then output of rng is madeodd, then store in BRAM
	-- When counter > t, then output of rng is made even, and then stored in BRAM
	random_output_odd  <= (random_output and std_logic_vector(to_signed(-3, 32))) OR std_logic_vector(to_unsigned(1, 32));
	random_output_even <= random_output and std_logic_vector(to_signed(-2, 32));

	-- use data in from sorting algorithm when state is sorting, otherwise use even/odd output from rng
	bram_data_in_a <= bram_data_in_a_sort when state_weight = sorting
		else random_output_even when generate_counter <= 2 * t
		else random_output_odd;

	bram_data_out_a_sort <= bram_data_out_a;

	-- When sorting, rewire enable signal
	bram_write_enable_a <= bram_write_enable_a_sort when state_weight = sorting else bram_write_enable_a_fsm;

	-- Port b is only used for sorting
	bram_address_b       <= bram_address_b_sort;
	bram_data_in_b       <= bram_data_in_b_sort;
	bram_data_out_b_sort <= bram_data_out_b;
	bram_write_enable_b  <= bram_write_enable_sort;

	sort_bram_inst : entity work.sort_bram
		generic map(
			WIDTH              => 32,
			ADDRESS_WIDTH      => p_num_bits,
			NUMBER_OF_ELEMENTS => p
		)
		port map(
			clock               => clock,
			reset               => reset,
			start               => sorting_start,
			done                => sorting_done,
			bram_address_a      => bram_address_a_sort,
			bram_write_a_enable => bram_write_enable_a_sort,
			bram_data_in_a      => bram_data_in_a_sort,
			bram_data_out_a     => bram_data_out_a_sort,
			bram_address_b      => bram_address_b_sort,
			bram_write_b_enable => bram_write_enable_sort,
			bram_data_in_b      => bram_data_in_b_sort,
			bram_data_out_b     => bram_data_out_b_sort
		);

	-- Use only lower 2 bits
	small_weights <= (signed(bram_data_out_a) and resize("011", 32)) - to_signed(1, 32);

	small_weights_out <= signed(small_weights(1 downto 0));

end architecture RTL;

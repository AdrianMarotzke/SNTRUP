library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.constants.all;
use work.data_type.all;

-- Core key generation
-- output g_recip and f with highest degree first
entity key_generation is
	port(
		clock                       : in  std_logic;
		reset                       : in  std_logic;
		start                       : in  std_logic;
		ready                       : out std_logic;
		done                        : out std_logic;
		output_h                    : out std_logic_vector(q_num_bits - 1 downto 0);
		output_h_valid              : out std_logic;
		output_h_ack                : in  std_logic;
		output_f                    : out std_logic_vector(1 downto 0);
		output_f_valid              : out std_logic;
		output_g_recip              : out std_logic_vector(1 downto 0);
		output_g_valid              : out std_logic;
		random_small_enable         : out std_logic;
		random_small_poly           : in  std_logic_vector(1 downto 0);
		small_weights_random_enable : out std_logic;
		small_weights_random_output : in  std_logic_vector(31 downto 0);
		to_rq_mult                  : out rq_multiplication_in_type;
		from_rq_mult                : in  rq_multiplication_out_type;
		to_small_weights            : out small_random_weights_in_type;
		from_small_weights          : in  small_random_weights_out_type
	);
end entity key_generation;

architecture RTL of key_generation is

	type state_type is (init_state, gen_g, gen_g_done, inv_g, wait_inv_g, check_inv_g, gen_f, wait_gen_f, inv_f, inv_f_done1, inv_f_done2, mult_fg_init, mult_fg, done_state);
	signal state_key_gen : state_type;

	signal random_small_enable_out : std_logic;
	signal random_small_counter    : integer range 0 to p;

	signal random_small_counter_delay : std_logic_vector(p_num_bits - 1 downto 0);

	signal r3_recip_start         : std_logic;
	signal r3_recip_poly_in       : std_logic_vector(1 downto 0);
	signal r3_recip_poly_out      : std_logic_vector(1 downto 0);
	signal r3_recip_done          : std_logic;
	signal r3_recip_is_invertable : std_logic;
	signal r3_recip_ready         : std_logic;
	signal r3_recip_output_valid  : std_logic;

	signal small_weigh_start   : std_logic;
	signal small_weights_valid : std_logic;
	signal small_weights_out   : signed(1 downto 0);
	signal small_weights_done  : std_logic;

	signal rq_recip3_start         : std_logic;
	signal rq_recip3_small_poly_in : std_logic_vector(1 downto 0);
	signal rq_recip3_ready         : std_logic;
	signal rq_recip3_output_poly   : std_logic_vector(q_num_bits - 1 downto 0);
	signal rq_recip3_output_valid  : std_logic;
	signal rq_recip3_done          : std_logic;
	signal rq_recip3_f_address     : std_logic_vector(p_num_bits - 1 downto 0);

	signal rq_mult_start             : std_logic;
	signal rq_mult_ready             : std_logic;
	signal rq_mult_output_valid      : std_logic;
	signal rq_mult_output            : std_logic_vector(q_num_bits - 1 downto 0);
	signal rq_mult_output_ack        : std_logic;
	signal rq_mult_done              : std_logic;
	signal rq_mult_bram_f_address_a  : std_logic_vector(p_num_bits - 1 downto 0);
	signal rq_mult_bram_f_data_out_a : std_logic_vector(q_num_bits - 1 downto 0);
	signal rq_mult_bram_f_address_b  : std_logic_vector(p_num_bits - 1 downto 0);
	signal rq_mult_bram_f_data_out_b : std_logic_vector(q_num_bits - 1 downto 0);
	signal rq_mult_bram_g_address_a  : std_logic_vector(p_num_bits - 1 downto 0);
	signal rq_mult_bram_g_data_out_a : std_logic_vector(2 - 1 downto 0);
	signal rq_mult_bram_g_address_b  : std_logic_vector(p_num_bits - 1 downto 0);
	signal rq_mult_bram_g_data_out_b : std_logic_vector(2 - 1 downto 0);

	signal bram_f_address_a  : std_logic_vector(p_num_bits - 1 downto 0);
	signal bram_f_write_a    : std_logic;
	signal bram_f_data_in_a  : std_logic_vector(q_num_bits - 1 downto 0);
	signal bram_f_data_out_a : std_logic_vector(q_num_bits - 1 downto 0);
	signal bram_f_address_b  : std_logic_vector(p_num_bits - 1 downto 0);
	signal bram_f_write_b    : std_logic;
	signal bram_f_data_in_b  : std_logic_vector(q_num_bits - 1 downto 0);
	signal bram_f_data_out_b : std_logic_vector(q_num_bits - 1 downto 0);

	signal bram_g_address_a  : std_logic_vector(p_num_bits - 1 downto 0);
	signal bram_g_write_a    : std_logic;
	signal bram_g_data_in_a  : std_logic_vector(2 - 1 downto 0);
	signal bram_g_data_out_a : std_logic_vector(2 - 1 downto 0);
	signal bram_g_address_b  : std_logic_vector(p_num_bits - 1 downto 0);
	signal bram_g_write_b    : std_logic;
	signal bram_g_data_in_b  : std_logic_vector(2 - 1 downto 0);
	signal bram_g_data_out_b : std_logic_vector(2 - 1 downto 0);

begin
	fsm_process : process(clock, reset) is
	begin
		if reset = '1' then
			state_key_gen <= init_state;

			ready                   <= '0';
			random_small_enable_out <= '0';
			r3_recip_start          <= '0';
			small_weigh_start       <= '0';
			done                    <= '0';
			rq_mult_start           <= '0';
			random_small_counter    <= 0;
		elsif rising_edge(clock) then
			case state_key_gen is
				when init_state =>
					if start = '1' then
						state_key_gen <= gen_f;
					else
						state_key_gen <= init_state;
					end if;
					ready <= '1';
					done  <= '0';
				when gen_g =>
					if random_small_counter = p - 1 then
						state_key_gen <= gen_g_done;
					else
						state_key_gen <= gen_g;
					end if;
					random_small_counter <= random_small_counter + 1;

					random_small_enable_out <= '1';
					r3_recip_start          <= '0';
				when gen_g_done =>
					state_key_gen           <= inv_g;
					random_small_enable_out <= '0';
					random_small_counter    <= 0;
				when inv_g =>
					state_key_gen           <= wait_inv_g;
					random_small_enable_out <= '0';
				when wait_inv_g =>
					if r3_recip_done = '0' then
						state_key_gen <= wait_inv_g;
					else
						if r3_recip_is_invertable = '1' then
							state_key_gen <= inv_f;
						else
							state_key_gen <= check_inv_g;
						end if;
					end if;
				when check_inv_g =>
					if r3_recip_ready = '1' then
						state_key_gen  <= gen_g;
						r3_recip_start <= '1';
					else
						state_key_gen <= check_inv_g;
					end if;
				when gen_f =>
					state_key_gen     <= wait_gen_f;
					small_weigh_start <= '1';
					ready             <= '0';
				when wait_gen_f =>
					if small_weights_done = '1' then
						state_key_gen  <= gen_g;
						r3_recip_start <= '1';
					end if;

					small_weigh_start <= '0';
				when inv_f =>
					if rq_recip3_ready = '0' then
						state_key_gen <= inv_f;
					else
						state_key_gen <= inv_f_done1;
					end if;
				when inv_f_done1 =>
					state_key_gen <= inv_f_done2;
				when inv_f_done2 =>
					state_key_gen <= mult_fg_init;
				when mult_fg_init =>
					state_key_gen <= mult_fg;
					rq_mult_start <= '1';
				when mult_fg =>
					if rq_mult_done = '0' then
						state_key_gen <= mult_fg;
					else
						state_key_gen <= done_state;
					end if;
					rq_mult_start <= '0';
				when done_state =>
					state_key_gen <= init_state;
					done          <= '1';
			end case;
		end if;
	end process fsm_process;

	r3_recip_poly_in <= random_small_poly;

	rq_recip3_start         <= small_weights_valid when rising_edge(clock);
	rq_recip3_small_poly_in <= std_logic_vector(small_weights_out) when rising_edge(clock); -- TODO is this clock really needed?

	-- rq_reciprocal outputs highest degree coeffiencts first, they have to put at high address
	f_address_counter : process(clock) is
		variable f_recip_address : integer range 0 to p;
	begin
		if rising_edge(clock) then
			if rq_recip3_output_valid = '0' then
				f_recip_address := 0;
			else
				f_recip_address := f_recip_address + 1;
			end if;
			rq_recip3_f_address <= std_logic_vector(to_unsigned(f_recip_address, p_num_bits));
		end if;
	end process f_address_counter;

	bram_f_write_a   <= rq_recip3_output_valid;
	bram_f_data_in_a <= rq_recip3_output_poly;
	bram_f_address_a <= rq_recip3_f_address when state_key_gen /= mult_fg else rq_mult_bram_f_address_a;

	bram_f_address_b <= rq_mult_bram_f_address_b;

	rq_mult_bram_f_data_out_a <= bram_f_data_out_a;
	rq_mult_bram_f_data_out_b <= bram_f_data_out_b;

	output_h           <= rq_mult_output;
	output_h_valid     <= rq_mult_output_valid;
	rq_mult_output_ack <= '1'; -- output_h_ack;

	output_f       <= std_logic_vector(small_weights_out);
	output_f_valid <= small_weights_valid;

	bram_g_write_a      <= random_small_enable_out; -- when rising_edge(clock);
	random_small_enable <= random_small_enable_out;

	random_small_counter_delay <= std_logic_vector(to_unsigned(random_small_counter, p_num_bits)) when rising_edge(clock);

	bram_g_address_a <= random_small_counter_delay when state_key_gen /= mult_fg else rq_mult_bram_g_address_a;
	bram_g_address_b <= rq_mult_bram_g_address_b;

	bram_g_data_in_a <= random_small_poly;

	bram_g_write_b <= '0';
	bram_f_write_b <= '0';

	rq_mult_bram_g_data_out_a <= bram_g_data_out_a;
	rq_mult_bram_g_data_out_b <= bram_g_data_out_b;

	output_g_valid <= r3_recip_output_valid and r3_recip_is_invertable;
	output_g_recip <= r3_recip_poly_out;

	r3_reciprocal_inst : entity work.r3_reciprocal
		port map(
			clock               => clock,
			reset               => reset,
			start               => r3_recip_start,
			small_polynomial_in => r3_recip_poly_in,
			ready               => r3_recip_ready,
			output_polynomial   => r3_recip_poly_out,
			output_valid        => r3_recip_output_valid,
			is_invertable       => r3_recip_is_invertable,
			done                => r3_recip_done
		);

	to_small_weights.random_output <= small_weights_random_output;
	to_small_weights.start         <= small_weigh_start;

	small_weights_done          <= from_small_weights.done;
	small_weights_random_enable <= from_small_weights.random_enable;
	small_weights_out           <= from_small_weights.small_weights_out;
	small_weights_valid         <= from_small_weights.small_weights_valid;

	rq_reciprocal_3_inst : entity work.rq_reciprocal_3
		port map(
			clock               => clock,
			reset               => reset,
			start               => rq_recip3_start,
			small_polynomial_in => rq_recip3_small_poly_in,
			ready               => rq_recip3_ready,
			output_polynomial   => rq_recip3_output_poly,
			output_valid        => rq_recip3_output_valid,
			done                => rq_recip3_done
		);

	to_rq_mult.start             <= rq_mult_start;
	to_rq_mult.output_ack        <= rq_mult_output_ack;
	to_rq_mult.bram_f_data_out_a <= rq_mult_bram_f_data_out_a;
	to_rq_mult.bram_f_data_out_b <= rq_mult_bram_f_data_out_b;
	to_rq_mult.bram_g_data_out_a <= rq_mult_bram_g_data_out_a;
	to_rq_mult.bram_g_data_out_b <= rq_mult_bram_g_data_out_b;
	rq_mult_ready                <= from_rq_mult.ready;
	rq_mult_output_valid         <= from_rq_mult.output_valid;
	rq_mult_output               <= from_rq_mult.output;
	rq_mult_done                 <= from_rq_mult.done;

	rq_mult_bram_f_address_a <= from_rq_mult.bram_f_address_a;
	rq_mult_bram_f_address_b <= from_rq_mult.bram_f_address_b;
	rq_mult_bram_g_address_a <= from_rq_mult.bram_g_address_a;
	rq_mult_bram_g_address_b <= from_rq_mult.bram_g_address_b;

	block_ram_f : entity work.block_ram
		generic map(
			ADDRESS_WIDTH => p_num_bits,
			DATA_WIDTH    => q_num_bits
		)
		port map(
			clock      => clock,
			address_a  => bram_f_address_a,
			write_a    => bram_f_write_a,
			data_in_a  => bram_f_data_in_a,
			data_out_a => bram_f_data_out_a,
			address_b  => bram_f_address_b,
			write_b    => bram_f_write_b,
			data_in_b  => bram_f_data_in_b,
			data_out_b => bram_f_data_out_b
		);

	block_ram_g : entity work.block_ram
		generic map(
			ADDRESS_WIDTH => p_num_bits,
			DATA_WIDTH    => 2
		)
		port map(
			clock      => clock,
			address_a  => bram_g_address_a,
			write_a    => bram_g_write_a,
			data_in_a  => bram_g_data_in_a,
			data_out_a => bram_g_data_out_a,
			address_b  => bram_g_address_b,
			write_b    => bram_g_write_b,
			data_in_b  => bram_g_data_in_b,
			data_out_b => bram_g_data_out_b
		);
end architecture RTL;

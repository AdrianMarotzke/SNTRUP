library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.constants.all;
use work.data_type.all;

-- Core key encapsulation of NTRU prime, without any de or encoding
-- Public key is input with highest degree first.
-- c is output with highest degree first
entity key_encapsulation is
	port(
		clock               : in  std_logic;
		reset               : in  std_logic;
		ready               : out std_logic;
		done                : out std_logic;
		start_encap         : in  std_logic;
		new_public_key      : in  std_logic;
		public_key_in       : in  std_logic_vector(q_num_bits - 1 downto 0);
		public_key_valid    : in  std_logic;
		public_key_ready    : out std_logic;
		c_encrypt           : out std_logic_vector(q_num_bits - 1 downto 0);
		c_encrypt_valid     : out std_logic;
		r_secret            : out std_logic_vector(1 downto 0);
		r_secret_valid      : out std_logic;
		small_weights_start : out std_logic;
		small_weights_out   : in  std_logic_vector(1 downto 0);
		small_weights_valid : in  std_logic;
		small_weights_done  : in  std_logic;
		to_rq_mult          : out rq_multiplication_in_type;
		from_rq_mult        : in  rq_multiplication_out_type;
		to_freeze_round     : out mod3_freeze_round_in_type;
		from_freeze_round   : in  mod3_freeze_round_out_type
	);
end entity key_encapsulation;

architecture RTL of key_encapsulation is

	type state_type is (init_state, write_public_key, ready_state, get_small_state, multiply_state, done_state);
	signal state_encap : state_type := init_state;

	signal p_counter : integer range 0 to p;

	signal rq_mult_start              : std_logic;
	signal rq_mult_ready              : std_logic;
	signal rq_mult_output_valid       : std_logic;
	signal rq_mult_output             : std_logic_vector(q_num_bits - 1 downto 0);
	signal rq_mult_output_ack         : std_logic;
	signal rq_mult_done               : std_logic;
	signal rq_mult_bram_pk_address_a  : std_logic_vector(p_num_bits - 1 downto 0);
	signal rq_mult_bram_pk_data_out_a : std_logic_vector(q_num_bits - 1 downto 0);
	signal rq_mult_bram_pk_address_b  : std_logic_vector(p_num_bits - 1 downto 0);
	signal rq_mult_bram_pk_data_out_b : std_logic_vector(q_num_bits - 1 downto 0);
	signal rq_mult_bram_r_address_a   : std_logic_vector(p_num_bits - 1 downto 0);
	signal rq_mult_bram_r_data_out_a  : std_logic_vector(2 - 1 downto 0);
	signal rq_mult_bram_r_address_b   : std_logic_vector(p_num_bits - 1 downto 0);
	signal rq_mult_bram_r_data_out_b  : std_logic_vector(2 - 1 downto 0);

	signal bram_pk_address_a  : std_logic_vector(p_num_bits - 1 downto 0);
	signal bram_pk_write_a    : std_logic;
	signal bram_pk_data_in_a  : std_logic_vector(q_num_bits - 1 downto 0);
	signal bram_pk_data_out_a : std_logic_vector(q_num_bits - 1 downto 0);
	signal bram_pk_address_b  : std_logic_vector(p_num_bits - 1 downto 0);
	signal bram_pk_write_b    : STD_LOGIC;
	signal bram_pk_data_in_b  : std_logic_vector(q_num_bits - 1 downto 0);
	signal bram_pk_data_out_b : std_logic_vector(q_num_bits - 1 downto 0);

	signal bram_r_address_a  : std_logic_vector(p_num_bits - 1 downto 0);
	signal bram_r_write_a    : std_logic;
	signal bram_r_data_in_a  : std_logic_vector(1 downto 0);
	signal bram_r_data_out_a : std_logic_vector(1 downto 0);
	signal bram_r_address_b  : std_logic_vector(p_num_bits - 1 downto 0);
	signal bram_r_write_b    : std_logic;
	signal bram_r_data_in_b  : std_logic_vector(1 downto 0);
	signal bram_r_data_out_b : std_logic_vector(1 downto 0);

	signal rq_round_input        : std_logic_vector(q_num_bits - 1 downto 0);
	signal rq_round_output       : std_logic_vector(q_num_bits - 1 downto 0);
	signal rq_round_input_valid  : std_logic;
	signal rq_round_output_valid : std_logic;

begin

	fsm_process : process(clock, reset) is
	begin
		if reset = '1' then
			state_encap <= init_state;

			ready               <= '0';
			done                <= '0';
			public_key_ready    <= '0';
			small_weights_start <= '0';
			rq_mult_start       <= '0';
		elsif rising_edge(clock) then
			case state_encap is
				when init_state =>
					if new_public_key = '1' then
						state_encap <= write_public_key;
					end if;
					p_counter        <= 0;
					ready            <= '1';
					public_key_ready <= '0';
				when write_public_key =>
					if public_key_valid = '1' and p_counter /= p - 1 then
						p_counter <= p_counter + 1;
					end if;
					if p_counter = p - 1 and public_key_valid = '1' then
						state_encap      <= ready_state;
						public_key_ready <= '1';
					end if;
					ready <= '0';
				when ready_state =>
					if start_encap = '1' AND new_public_key = '0' then
						state_encap         <= get_small_state;
						small_weights_start <= '1';
						p_counter           <= 0;
					end if;
					if new_public_key = '1' then
						state_encap      <= write_public_key;
						p_counter        <= 0;
						public_key_ready <= '0';
					end if;
					ready <= '1';
					done  <= '0';
				when get_small_state =>
					if small_weights_valid = '1' then
						p_counter <= p_counter + 1;
					end if;
					if small_weights_done = '1' AND p_counter = p then
						state_encap   <= multiply_state;
						rq_mult_start <= '1';
					end if;
					small_weights_start <= '0';
					ready               <= '0';

				when multiply_state =>
					if rq_mult_done = '1' then
						state_encap <= done_state;
					end if;
					rq_mult_start <= '0';
				when done_state =>
					if rq_round_output_valid = '0' then
						state_encap <= ready_state;
						done        <= '1';
					end if;
			end case;
		end if;
	end process fsm_process;

	bram_pk_data_in_a <= public_key_in;
	bram_pk_write_a   <= public_key_valid when state_encap = write_public_key else '0';
	bram_pk_address_a <= std_logic_vector(to_unsigned(p_counter, p_num_bits)) when state_encap = write_public_key else rq_mult_bram_pk_address_a;

	bram_r_data_in_a <= std_logic_vector(small_weights_out);
	bram_r_write_a   <= small_weights_valid when state_encap = get_small_state else '0';
	bram_r_address_a <= std_logic_vector(to_unsigned(p_counter, p_num_bits)) when state_encap = get_small_state else rq_mult_bram_r_address_a;

	bram_pk_address_b <= rq_mult_bram_pk_address_b;
	bram_r_address_b  <= rq_mult_bram_r_address_b;

	rq_mult_bram_pk_data_out_a <= bram_pk_data_out_a;
	rq_mult_bram_pk_data_out_b <= bram_pk_data_out_b;
	rq_mult_bram_r_data_out_a  <= bram_r_data_out_a;
	rq_mult_bram_r_data_out_b  <= bram_r_data_out_b;

	rq_round_input       <= rq_mult_output;
	rq_round_input_valid <= rq_mult_output_valid;

	c_encrypt       <= std_logic_vector(shift_right((resize(signed(rq_round_output), q_num_bits + 2) + q12) * 10923, 15)(q_num_bits - 1 downto 0)) when rising_edge(clock);
	c_encrypt_valid <= rq_round_output_valid when rising_edge(clock);

	r_secret       <= std_logic_vector(small_weights_out);
	r_secret_valid <= small_weights_valid;

	rq_mult_output_ack <= '1';

	to_rq_mult.start             <= rq_mult_start;
	to_rq_mult.output_ack        <= rq_mult_output_ack;
	to_rq_mult.bram_f_data_out_a <= rq_mult_bram_pk_data_out_a;
	to_rq_mult.bram_f_data_out_b <= rq_mult_bram_pk_data_out_b;
	to_rq_mult.bram_g_data_out_a <= rq_mult_bram_r_data_out_a;
	to_rq_mult.bram_g_data_out_b <= rq_mult_bram_r_data_out_b;
	rq_mult_ready                <= from_rq_mult.ready;
	rq_mult_output_valid         <= from_rq_mult.output_valid;
	rq_mult_output               <= from_rq_mult.output;
	rq_mult_done                 <= from_rq_mult.done;

	rq_mult_bram_pk_address_a <= from_rq_mult.bram_f_address_a;
	rq_mult_bram_pk_address_b <= from_rq_mult.bram_f_address_b;
	rq_mult_bram_r_address_a  <= from_rq_mult.bram_g_address_a;
	rq_mult_bram_r_address_b  <= from_rq_mult.bram_g_address_b;

	to_freeze_round.input  <= signed(rq_round_input);
	to_freeze_round.enable <= rq_round_input_valid;

	rq_round_output       <= std_logic_vector(from_freeze_round.output_rounded);
	rq_round_output_valid <= from_freeze_round.output_valid;

	block_ram_pk : entity work.block_ram
		generic map(
			ADDRESS_WIDTH => p_num_bits,
			DATA_WIDTH    => q_num_bits
		)
		port map(
			clock      => clock,
			address_a  => bram_pk_address_a,
			write_a    => bram_pk_write_a,
			data_in_a  => bram_pk_data_in_a,
			data_out_a => bram_pk_data_out_a,
			address_b  => bram_pk_address_b,
			write_b    => bram_pk_write_b,
			data_in_b  => bram_pk_data_in_b,
			data_out_b => bram_pk_data_out_b
		);

	block_ram_r : entity work.block_ram
		generic map(
			ADDRESS_WIDTH => p_num_bits,
			DATA_WIDTH    => 2
		)
		port map(
			clock      => clock,
			address_a  => bram_r_address_a,
			write_a    => bram_r_write_a,
			data_in_a  => bram_r_data_in_a,
			data_out_a => bram_r_data_out_a,
			address_b  => bram_r_address_b,
			write_b    => bram_r_write_b,
			data_in_b  => bram_r_data_in_b,
			data_out_b => bram_r_data_out_b
		);

	-- Unused, tied to zero
	bram_r_write_b  <= '0';
	bram_pk_write_b <= '0';
end architecture RTL;

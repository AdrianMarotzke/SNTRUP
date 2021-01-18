library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.constants.all;
use work.data_type.all;

-- Top Module
entity ntru_prime_top is
	port(
		clock                 : in  std_logic;
		reset                 : in  std_logic;
		ready                 : out std_logic;
		done                  : out std_logic;
		start_key_gen         : in  std_logic;
		start_encap           : in  std_logic;
		start_decap           : in  std_logic;
		set_new_public_key    : in  std_logic;
		public_key_in         : in  std_logic_vector(7 downto 0);
		public_key_in_valid   : in  std_logic;
		public_key_in_ack     : out std_logic;
		public_key_is_set     : out std_logic;
		set_new_private_key   : in  std_logic;
		private_key_in        : in  std_logic_vector(7 downto 0);
		private_key_in_valid  : in  std_logic;
		private_key_in_ack    : out std_logic;
		private_key_is_set    : out std_logic;
		cipher_output         : out std_logic_vector(7 downto 0);
		cipher_output_valid   : out std_logic;
		cipher_input          : in  std_logic_vector(7 downto 0);
		cipher_input_valid    : in  std_logic;
		cipher_input_ack      : out std_logic;
		k_hash_out            : out std_logic_vector(63 downto 0);
		k_out_valid           : out std_logic;
		private_key_out       : out std_logic_vector(7 downto 0);
		private_key_out_valid : out std_logic;
		public_key_out        : out std_logic_vector(7 downto 0);
		public_key_out_valid  : out std_logic;
		random_enable         : out std_logic;
		random_output         : in  std_logic_vector(31 downto 0)
	);
end entity ntru_prime_top;

architecture RTL of ntru_prime_top is

	type state_type is (IDLE, PREPARE_ENCAP, PREPARE_DECAP, ENCAP, DECAP, KEY_GEN);
	signal state_top : state_type;

	signal key_encap_public_key_in               : std_logic_vector(7 downto 0);
	signal key_encap_public_key_valid            : std_logic;
	signal key_encap_public_key_in_ack           : std_logic;
	signal key_encap_public_key_new              : std_logic;
	signal key_encap_public_key_is_set           : std_logic;
	signal key_encap_ready                       : std_logic;
	signal key_encap_start_encap                 : std_logic;
	signal key_encap_cipher_output               : std_logic_vector(7 downto 0);
	signal key_encap_cipher_output_valid         : std_logic;
	signal key_encap_k_hash_out                  : std_logic_vector(63 downto 0);
	signal key_encap_k_out_valid                 : std_logic;
	signal key_encap_done                        : std_logic;
	signal key_encap_small_weights_random_enable : std_logic;
	signal key_encap_small_weights_random_output : std_logic_vector(31 downto 0);
	signal key_encap_to_sha                      : sha_record_in_type;
	signal key_encap_from_sha                    : sha_record_out_type;
	signal key_encap_to_decode_Rq                : decode_Rq_in_type;
	signal key_encap_from_decode_Rq              : decode_Rq_out_type;
	signal key_encap_to_encode_Rq                : encode_Rq_in_type;
	signal key_encap_from_encode_Rq              : encode_Rq_out_type;
	signal key_encap_to_encap_core               : encap_core_in_type;
	signal key_encap_from_encap_core             : encap_core_out_type;
	signal key_encap_to_small_weights            : small_random_weights_in_type;
	signal key_encap_from_small_weights          : small_random_weights_out_type;

	signal key_decap_secret_key_in      : std_logic_vector(7 downto 0);
	signal key_decap_secret_key_valid   : std_logic;
	signal key_decap_secret_key_in_ack  : std_logic;
	signal key_decap_key_new            : std_logic;
	signal key_decap_key_is_set         : std_logic;
	signal key_decap_ready              : std_logic;
	signal key_decap_start_decap        : std_logic;
	signal key_decap_cipher_input       : std_logic_vector(7 downto 0);
	signal key_decap_cipher_input_valid : std_logic;
	signal key_decap_cipher_input_ack   : std_logic;
	signal key_decap_k_hash_out         : std_logic_vector(63 downto 0);
	signal key_decap_k_out_valid        : std_logic;
	signal key_decap_done               : std_logic;
	signal key_decap_to_sha             : sha_record_in_type;
	signal key_decap_from_sha           : sha_record_out_type;
	signal key_decap_to_decode_Rq       : decode_Rq_in_type;
	signal key_decap_from_decode_Rq     : decode_Rq_out_type;
	signal key_decap_to_encode_Rq       : encode_Rq_in_type;
	signal key_decap_from_encode_Rq     : encode_Rq_out_type;
	signal key_decap_to_encap_core      : encap_core_in_type;
	signal key_decap_from_encap_core    : encap_core_out_type;
	signal key_decap_to_rq_mult         : rq_multiplication_in_type;
	signal key_decap_from_rq_mult       : rq_multiplication_out_type;
	signal key_decap_to_freeze_round    : mod3_freeze_round_in_type;
	signal key_decap_from_freeze_round  : mod3_freeze_round_out_type;

	signal encap_core_in                : encap_core_in_type;
	signal encap_core_out               : encap_core_out_type;
	signal encap_core_to_rq_mult        : rq_multiplication_in_type;
	signal encap_core_from_rq_mult      : rq_multiplication_out_type;
	signal encap_core_to_freeze_round   : mod3_freeze_round_in_type;
	signal encap_core_from_freeze_round : mod3_freeze_round_out_type;

	signal key_gen_start            : std_logic;
	signal key_gen_ready            : std_logic;
	signal key_gen_done             : std_logic;
	signal key_gen_encoded_pk       : std_logic_vector(7 downto 0);
	signal key_gen_encoded_pk_valid : std_logic;

	signal key_gen_random_small_enable         : std_logic;
	signal key_gen_random_small_poly           : std_logic_vector(1 downto 0);
	signal key_gen_small_weights_random_enable : std_logic;
	signal key_gen_small_weights_random_output : std_logic_vector(31 downto 0);
	signal key_gen_to_encode_Rq                : encode_Rq_in_type;
	signal key_gen_from_encode_Rq              : encode_Rq_out_type;
	signal key_gen_to_rq_mult                  : rq_multiplication_in_type;
	signal key_gen_from_rq_mult                : rq_multiplication_out_type;
	signal key_gen_to_small_weights            : small_random_weights_in_type;
	signal key_gen_from_small_weights          : small_random_weights_out_type;
	signal key_gen_to_sha                      : sha_record_in_type;
	signal key_gen_from_sha                    : sha_record_out_type;

	signal decode_Rq_record_in  : decode_Rq_in_type;
	signal decode_Rq_record_out : decode_Rq_out_type;

	signal encode_Rq_record_in  : encode_Rq_in_type;
	signal encode_Rq_record_out : encode_Rq_out_type;

	signal rq_mult_in  : rq_multiplication_in_type;
	signal rq_mult_out : rq_multiplication_out_type;

	signal sha_record_in  : sha_record_in_type;
	signal sha_record_out : sha_record_out_type;

	signal key_decap_reencap_true : std_logic;

	signal small_weights_in  : small_random_weights_in_type;
	signal small_weights_out : small_random_weights_out_type;

	signal mod3_freeze_round_in  : mod3_freeze_round_in_type;
	signal mod3_freeze_round_out : mod3_freeze_round_out_type;

	constant three_fffffff : std_logic_vector(31 downto 0) := "00111111111111111111111111111111";
begin

	fsm_process : process(clock, reset) is
	begin
		if reset = '1' then
			state_top <= IDLE;
			ready     <= '0';
			done      <= '0';
		elsif rising_edge(clock) then
			case state_top is
				when IDLE =>
					if start_encap = '1' and (key_encap_public_key_is_set = '1' or set_new_public_key = '1') then
						state_top <= ENCAP;
					end if;
					if start_decap = '1' and key_decap_key_is_set = '1' then
						state_top <= DECAP;
					end if;
					if start_key_gen = '1' then
						state_top <= KEY_GEN;
					end if;
					if set_new_public_key = '1' and start_encap ='0' then
						state_top <= PREPARE_ENCAP;
					end if;
					if set_new_private_key = '1' then
						state_top <= PREPARE_DECAP;
					end if;

					ready <= '1';
					done  <= '0';
				when PREPARE_ENCAP =>
					if key_encap_public_key_is_set = '1' then
						state_top <= IDLE;
						done      <= '1';
					end if;

					ready <= '0';
				when PREPARE_DECAP =>
					if key_decap_key_is_set = '1' then
						state_top <= IDLE;
						done      <= '1';
					end if;

					ready <= '0';

				when ENCAP =>
					if key_encap_done = '1' then
						state_top <= IDLE;
						done      <= '1';
					end if;

					ready <= '0';
				when DECAP =>
					if key_decap_done = '1' then
						state_top <= IDLE;
						done      <= '1';
					end if;
					ready <= '0';
				when KEY_GEN =>
					if key_gen_done = '1' then
						state_top <= IDLE;
						done      <= '1';
					end if;
					ready <= '0';
			end case;
		end if;
	end process fsm_process;

	random_enable                         <= key_gen_small_weights_random_enable or key_encap_small_weights_random_enable or key_gen_random_small_enable;
	key_encap_small_weights_random_output <= random_output;
	key_gen_small_weights_random_output   <= random_output;

	key_encap_public_key_in    <= public_key_in;
	key_encap_public_key_valid <= public_key_in_valid;
	public_key_in_ack          <= key_encap_public_key_in_ack;
	key_encap_public_key_new   <= set_new_public_key;
	public_key_is_set          <= key_encap_public_key_is_set;

	key_encap_start_encap <= start_encap;

	cipher_output       <= key_encap_cipher_output;
	cipher_output_valid <= key_encap_cipher_output_valid;
	k_hash_out          <= key_encap_k_hash_out when state_top = ENCAP else key_decap_k_hash_out;
	k_out_valid         <= key_encap_k_out_valid when state_top = ENCAP else key_decap_k_out_valid;

	key_decap_secret_key_in    <= private_key_in;
	key_decap_secret_key_valid <= private_key_in_valid;
	private_key_in_ack         <= key_decap_secret_key_in_ack;
	key_decap_key_new          <= set_new_private_key;
	private_key_is_set         <= key_decap_key_is_set;

	key_decap_cipher_input       <= cipher_input;
	key_decap_cipher_input_valid <= cipher_input_valid;
	cipher_input_ack             <= key_decap_cipher_input_ack;

	key_decap_start_decap <= start_decap;

	key_gen_start <= start_key_gen;

	key_gen_random_small_poly <= std_logic_vector(shift_right(unsigned(random_output and three_fffffff) * 3, 30)(1 downto 0) - 1);

	public_key_out       <= key_gen_encoded_pk;
	public_key_out_valid <= key_gen_encoded_pk_valid;

	key_encap_wrapper_inst : entity work.key_encap_wrapper
		port map(
			clock                       => clock,
			reset                       => reset,
			public_key_in               => key_encap_public_key_in,
			public_key_valid            => key_encap_public_key_valid,
			public_key_in_ack           => key_encap_public_key_in_ack,
			public_key_new              => key_encap_public_key_new,
			public_key_is_set           => key_encap_public_key_is_set,
			ready                       => key_encap_ready,
			start_encap                 => key_encap_start_encap,
			cipher_output               => key_encap_cipher_output,
			cipher_output_valid         => key_encap_cipher_output_valid,
			k_hash_out                  => key_encap_k_hash_out,
			k_out_valid                 => key_encap_k_out_valid,
			done                        => key_encap_done,
			small_weights_random_enable => key_encap_small_weights_random_enable,
			small_weights_random_output => key_encap_small_weights_random_output,
			to_sha                      => key_encap_to_sha,
			from_sha                    => key_encap_from_sha,
			to_decode_Rq                => key_encap_to_decode_Rq,
			from_decode_Rq              => key_encap_from_decode_Rq,
			to_encode_Rq                => key_encap_to_encode_Rq,
			from_encode_Rq              => key_encap_from_encode_Rq,
			to_encap_core               => key_encap_to_encap_core,
			from_encap_core             => key_encap_from_encap_core,
			to_small_weights            => key_encap_to_small_weights,
			from_small_weights          => key_encap_from_small_weights
		);

	key_decap_wrapper_inst : entity work.key_decap_wrapper
		port map(
			clock              => clock,
			reset              => reset,
			secret_key_in      => key_decap_secret_key_in,
			secret_key_valid   => key_decap_secret_key_valid,
			secret_key_in_ack  => key_decap_secret_key_in_ack,
			key_new            => key_decap_key_new,
			key_is_set         => key_decap_key_is_set,
			ready              => key_decap_ready,
			start_decap        => key_decap_start_decap,
			cipher_input       => key_decap_cipher_input,
			cipher_input_valid => key_decap_cipher_input_valid,
			cipher_input_ack   => key_decap_cipher_input_ack,
			k_hash_out         => key_decap_k_hash_out,
			k_out_valid        => key_decap_k_out_valid,
			done               => key_decap_done,
			to_sha             => key_decap_to_sha,
			from_sha           => key_decap_from_sha,
			to_decode_Rq       => key_decap_to_decode_Rq,
			from_decode_Rq     => key_decap_from_decode_Rq,
			to_encode_Rq       => key_decap_to_encode_Rq,
			from_encode_Rq     => key_decap_from_encode_Rq,
			to_encap_core      => key_decap_to_encap_core,
			from_encap_core    => key_decap_from_encap_core,
			reencap_true       => key_decap_reencap_true,
			to_rq_mult         => key_decap_to_rq_mult,
			from_rq_mult       => key_decap_from_rq_mult,
			to_freeze_round    => key_decap_to_freeze_round,
			from_freeze_round  => key_decap_from_freeze_round
		);

	key_gen_wrapper_inst : entity work.key_gen_wrapper
		port map(
			clock                  => clock,
			reset                  => reset,
			start                  => key_gen_start,
			ready                  => key_gen_ready,
			done                   => key_gen_done,
			encoded_pk             => key_gen_encoded_pk,
			encoded_pk_valid       => key_gen_encoded_pk_valid,
			private_key_out        => private_key_out,
			private_key_out_valid  => private_key_out_valid,
			random_small_enable    => key_gen_random_small_enable,
			random_small_poly      => key_gen_random_small_poly,
			random_enable          => key_gen_small_weights_random_enable,
			random_output          => key_gen_small_weights_random_output,
			to_sha                 => key_gen_to_sha,
			from_sha               => key_gen_from_sha,
			to_encode_Rq           => key_gen_to_encode_Rq,
			from_encode_Rq         => key_gen_from_encode_Rq,
			to_rq_mult             => key_gen_to_rq_mult,
			from_rq_mult           => key_gen_from_rq_mult,
			to_small_weights       => key_gen_to_small_weights,
			from_small_weights     => key_gen_from_small_weights
		);

	-----------------------------------------------------------------------------------------------
	------------------- Shared modules
	-----------------------------------------------------------------------------------------------

	encap_core_in             <= key_encap_to_encap_core when state_top = ENCAP or state_top = PREPARE_ENCAP else key_decap_to_encap_core;
	key_encap_from_encap_core <= encap_core_out;
	key_decap_from_encap_core <= encap_core_out;

	key_encap_shared_core : entity work.key_encapsulation
		port map(
			clock               => clock,
			reset               => reset,
			ready               => encap_core_out.ready,
			done                => encap_core_out.done,
			start_encap         => encap_core_in.start_encap,
			new_public_key      => encap_core_in.new_public_key,
			public_key_in       => encap_core_in.public_key_in,
			public_key_valid    => encap_core_in.public_key_valid,
			public_key_ready    => encap_core_out.public_key_ready,
			c_encrypt           => encap_core_out.c_encrypt,
			c_encrypt_valid     => encap_core_out.c_encrypt_valid,
			r_secret            => encap_core_out.r_secret,
			r_secret_valid      => encap_core_out.r_secret_valid,
			small_weights_start => encap_core_out.small_weights_start,
			small_weights_out   => encap_core_in.small_weights_out,
			small_weights_valid => encap_core_in.small_weights_valid,
			small_weights_done  => encap_core_in.small_weights_done,
			to_rq_mult          => encap_core_to_rq_mult,
			from_rq_mult        => encap_core_from_rq_mult,
			to_freeze_round     => encap_core_to_freeze_round,
			from_freeze_round   => encap_core_from_freeze_round
		);

	small_weights_in             <= key_encap_to_small_weights when state_top = ENCAP else key_gen_to_small_weights;
	key_gen_from_small_weights   <= small_weights_out when state_top = KEY_GEN else ('0', "00", '0', '0');
	key_encap_from_small_weights <= small_weights_out when state_top = ENCAP or state_top = PREPARE_ENCAP else ('0', "00", '0', '0');

	small_random_weights_inst : entity work.small_random_weights
		port map(
			clock               => clock,
			reset               => reset,
			start               => small_weights_in.start,
			small_weights_valid => small_weights_out.small_weights_valid,
			small_weights_out   => small_weights_out.small_weights_out,
			done                => small_weights_out.done,
			random_enable       => small_weights_out.random_enable,
			random_output       => small_weights_in.random_output
		);

	decode_Rq_record_in      <= key_encap_to_decode_Rq when state_top = ENCAP or state_top = PREPARE_ENCAP else key_decap_to_decode_Rq;
	key_encap_from_decode_Rq <= decode_Rq_record_out;
	key_decap_from_decode_Rq <= decode_Rq_record_out;

	decode_Rq_inst : entity work.decode_Rq
		port map(
			clock          => clock,
			reset          => reset,
			start          => decode_Rq_record_in.start,
			input          => decode_Rq_record_in.input,
			input_valid    => decode_Rq_record_in.input_valid,
			input_ack      => decode_Rq_record_out.input_ack,
			rounded_decode => decode_Rq_record_in.rounded_decode,
			output         => decode_Rq_record_out.output,
			output_valid   => decode_Rq_record_out.output_valid,
			done           => decode_Rq_record_out.done
		);

	encode_Rq_record_in <= key_encap_to_encode_Rq when state_top = ENCAP or state_top = PREPARE_ENCAP
	                       else key_decap_to_encode_Rq when state_top = DECAP
	                       else key_gen_to_encode_Rq;

	key_encap_from_encode_Rq <= encode_Rq_record_out when state_top = ENCAP or state_top = PREPARE_ENCAP else encode_Rq_out_constant_zero;
	key_decap_from_encode_Rq <= encode_Rq_record_out when state_top = DECAP else encode_Rq_out_constant_zero;
	key_gen_from_encode_Rq   <= encode_Rq_record_out when state_top = KEY_GEN else encode_Rq_out_constant_zero;

	encode_Rq_inst : entity work.encode_Rq
		port map(
			clock        => clock,
			reset        => reset,
			input        => encode_Rq_record_in.input,
			input_valid  => encode_Rq_record_in.input_valid,
			m_input      => encode_Rq_record_in.m_input,
			input_ack    => encode_Rq_record_out.input_ack,
			output       => encode_Rq_record_out.output,
			output_valid => encode_Rq_record_out.output_valid,
			done         => encode_Rq_record_out.done
		);

	rq_mult_in <= encap_core_to_rq_mult when state_top = ENCAP or state_top = PREPARE_ENCAP or key_decap_reencap_true = '1'
	              else key_decap_to_rq_mult when state_top = DECAP and key_decap_reencap_true = '0'
	              else key_gen_to_rq_mult;

	encap_core_from_rq_mult <= rq_mult_out when state_top = ENCAP or state_top = PREPARE_ENCAP or key_decap_reencap_true = '1' else rq_mult_out_type_zero;
	key_decap_from_rq_mult  <= rq_mult_out when state_top = DECAP and key_decap_reencap_true = '0' else rq_mult_out_type_zero;
	key_gen_from_rq_mult    <= rq_mult_out when state_top = KEY_GEN else rq_mult_out_type_zero;

	rq_multiplication_inst : entity work.rq_mult_karatsuba_2bit
		generic map(
			q_num_bits        => q_num_bits,
			q                 => q,
			q_half            => q_half,
			p_num_bits        => p_num_bits,
			p                 => p,
			layer_2_karatsuba => use_2nd_layer_karatsuba
		)
		port map(
			clock             => clock,
			reset             => reset,
			start             => rq_mult_in.start,
			ready             => rq_mult_out.ready,
			output_valid      => rq_mult_out.output_valid,
			output            => rq_mult_out.output,
			output_ack        => rq_mult_in.output_ack,
			done              => rq_mult_out.done,
			bram_f_address_a  => rq_mult_out.bram_f_address_a,
			bram_f_data_out_a => rq_mult_in.bram_f_data_out_a,
			bram_f_address_b  => rq_mult_out.bram_f_address_b,
			bram_f_data_out_b => rq_mult_in.bram_f_data_out_b,
			bram_g_address_a  => rq_mult_out.bram_g_address_a,
			bram_g_data_out_a => rq_mult_in.bram_g_data_out_a,
			bram_g_address_b  => rq_mult_out.bram_g_address_b,
			bram_g_data_out_b => rq_mult_in.bram_g_data_out_b
		);

	sha_record_in      <= key_encap_to_sha when state_top = ENCAP or state_top = PREPARE_ENCAP or state_top = IDLE
	                      else key_decap_to_sha when state_top = DECAP or state_top = PREPARE_DECAP
	                      else key_gen_to_sha;
	key_encap_from_sha <= sha_record_out;
	key_decap_from_sha <= sha_record_out;
	key_gen_from_sha   <= sha_record_out;

	sha_512_wrapper_inst : entity work.sha_512_wrapper
		port map(
			clock                 => clock,
			reset                 => reset,
			new_public_key        => sha_record_in.new_public_key,
			public_key_in         => sha_record_in.public_key_in,
			public_key_ready      => sha_record_in.public_key_ready,
			new_pk_cache          => sha_record_in.new_pk_cache,
			pk_cache_in           => sha_record_in.pk_cache_in,
			pk_cache_valid        => sha_record_in.pk_cache_in_valid,
			start_confirm         => sha_record_in.start_confirm,
			r_encoded_in          => sha_record_in.r_encoded_in,
			r_encoded_in_valid    => sha_record_in.r_encoded_in_valid,
			start_session         => sha_record_in.start_session,
			re_encap_session      => sha_record_in.re_encap_session,
			diff_mask             => sha_record_in.diff_mask,
			c_encoded_in          => sha_record_in.c_encoded_in,
			c_encoded_in_valid    => sha_record_in.c_encoded_in_valid,
			decode_Rq_input_ack   => sha_record_in.decode_Rq_input_ack,
			decode_Rq_input_valid => sha_record_in.decode_Rq_input_valid,
			sha_512_finished      => sha_record_out.hash_finished,
			ack_new_input         => sha_record_out.hash_ack_new_input,
			sha_512_hash_out      => sha_record_out.hash_out,
			hash_out_address      => sha_record_in.hash_out_address,
			hash_out_read_pub_key => sha_record_in.hash_out_read_pub_key,
			hash_out_read_confirm => sha_record_in.hash_out_read_confirm,
			hash_out_read_enable  => sha_record_in.hash_out_read_en
		);

	mod3_freeze_round_in <= encap_core_to_freeze_round when state_top = ENCAP or key_decap_reencap_true = '1' else key_decap_to_freeze_round;

	encap_core_from_freeze_round <= mod3_freeze_round_out when state_top = ENCAP or key_decap_reencap_true = '1' else mod3_freeze_round_zero;
	key_decap_from_freeze_round  <= mod3_freeze_round_out when state_top = DECAP and key_decap_reencap_true = '0' else mod3_freeze_round_zero; -- TODO the when else clause might not be needed 

	mod3_freeze_round_inst : entity work.mod3_freeze
		port map(
			clock          => clock,
			reset          => reset,
			input          => mod3_freeze_round_in.input,
			enable         => mod3_freeze_round_in.enable,
			output         => mod3_freeze_round_out.output,
			output_rounded => mod3_freeze_round_out.output_rounded,
			output_valid   => mod3_freeze_round_out.output_valid
		);

end architecture RTL;

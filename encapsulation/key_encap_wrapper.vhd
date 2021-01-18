library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.constants.all;
use work.data_type.all;

-- Wrapper for core encapsulation, contains en and decoding, and hashing
entity key_encap_wrapper is
	port(
		clock                       : in  std_logic;
		reset                       : in  std_logic;
		public_key_in               : in  std_logic_vector(7 downto 0);
		public_key_valid            : in  std_logic;
		public_key_in_ack           : out std_logic;
		public_key_new              : in  std_logic;
		public_key_is_set           : out std_logic;
		ready                       : out std_logic;
		start_encap                 : in  std_logic;
		cipher_output               : out std_logic_vector(7 downto 0);
		cipher_output_valid         : out std_logic;
		k_hash_out                  : out std_logic_vector(63 downto 0);
		k_out_valid                 : out std_logic;
		done                        : out std_logic;
		small_weights_random_enable : out std_logic;
		small_weights_random_output : in  std_logic_vector(31 downto 0);
		to_sha                      : out sha_record_in_type;
		from_sha                    : in  sha_record_out_type;
		to_decode_Rq                : out decode_Rq_in_type;
		from_decode_Rq              : in  decode_Rq_out_type;
		to_encode_Rq                : out encode_Rq_in_type;
		from_encode_Rq              : in  encode_Rq_out_type;
		to_encap_core               : out encap_core_in_type;
		from_encap_core             : in  encap_core_out_type;
		to_small_weights            : out small_random_weights_in_type;
		from_small_weights          : in  small_random_weights_out_type
	);
end entity key_encap_wrapper;

architecture RTL of key_encap_wrapper is

	type state_type is (idle, new_key, new_key_and_encap, key_ready, encap, encap_done, encode_c, encode_done, output_confirm, wait_hash, read_hash_out, done_state);
	signal state_enc_wrap : state_type;

	signal key_encap_ready            : std_logic;
	signal key_encap_done             : std_logic;
	signal key_encap_start_encap      : std_logic;
	signal key_encap_new_public_key   : std_logic;
	signal key_encap_public_key_in    : std_logic_vector(q_num_bits - 1 downto 0);
	signal key_encap_public_key_valid : std_logic;
	signal key_encap_public_key_ready : std_logic;
	signal key_encap_c_encrypt        : std_logic_vector(q_num_bits - 1 downto 0);
	signal key_encap_c_encrypt_valid  : std_logic;
	signal key_encap_r_secret         : std_logic_vector(1 downto 0);
	signal key_encap_r_secret_valid   : std_logic;

	signal small_weights_start : std_logic;
	signal small_weights_valid : std_logic;
	signal small_weights_out   : signed(1 downto 0);
	signal small_weights_done  : std_logic;

	signal decode_Rq_start        : std_logic;
	signal decode_Rq_input        : std_logic_vector(7 downto 0);
	signal decode_Rq_input_valid  : std_logic;
	signal decode_Rq_input_ack    : std_logic;
	signal decode_Rq_output       : std_logic_vector(q_num_bits - 1 downto 0);
	signal decode_Rq_output_valid : std_logic;
	signal decode_Rq_done         : std_logic;

	signal decode_Rq_output_shift : std_logic_vector(q_num_bits downto 0);

	signal encode_Rq_input        : std_logic_vector(q_num_bits - 1 downto 0);
	signal encode_Rq_input_valid  : std_logic;
	signal encode_Rq_input_ack    : std_logic;
	signal encode_Rq_m_input      : std_logic_vector(15 downto 0);
	signal encode_Rq_output       : std_logic_vector(7 downto 0);
	signal encode_Rq_output_valid : std_logic;
	signal encode_Rq_done         : std_logic;

	signal encode_Zx_input        : std_logic_vector(1 downto 0);
	signal encode_Zx_input_valid  : std_logic;
	signal encode_Zx_output       : std_logic_vector(7 downto 0);
	signal encode_Zx_output_valid : std_logic;
	signal encode_Zx_done         : std_logic;

	signal buffer_address_a : std_logic_vector(p_num_bits - 1 downto 0);
	signal buffer_write_a   : std_logic;
	signal buffer_data_in_a : std_logic_vector(q_num_bits - 1 downto 0);

	signal buffer_address_b  : std_logic_vector(p_num_bits - 1 downto 0);
	signal buffer_data_out_b : std_logic_vector(q_num_bits - 1 downto 0);

	signal address_b_var : integer range 0 to p;

	signal sha_finished      : std_logic;
	signal sha_ack_new_input : std_logic;
	signal sha_hash_out      : std_logic_vector(63 downto 0);

	signal sha_r_encoded_in       : std_logic_vector(7 downto 0);
	signal sha_r_encoded_in_valid : std_logic;
	signal sha_start_confirm      : std_logic;

	signal sha_start_session      : std_logic;
	signal sha_c_encoded_in       : std_logic_vector(7 downto 0);
	signal sha_c_encoded_in_valid : std_logic;

	signal confirm_counter      : integer range 0 to 32;
	signal cipher_confirm_valid : std_logic;
	signal cipher_confirm       : std_logic_vector(7 downto 0);

	signal sha_record_in  : sha_record_in_type;
	signal sha_record_out : sha_record_out_type;

	signal sha_hash_out_address : integer range 0 to 3;
	signal sha_hash_out_read_en : std_logic;
	signal sha_hash_out_counter : integer range 0 to 8;

	signal sha_hash_out_read_confirm : std_logic;
begin

	fsm_process : process(clock, reset) is
	begin
		if reset = '1' then
			state_enc_wrap            <= idle;
			ready                     <= '0';
			public_key_is_set         <= '0';
			key_encap_new_public_key  <= '0';
			decode_Rq_start           <= '0';
			key_encap_start_encap     <= '0';
			encode_Rq_input_valid     <= '0';
			sha_start_confirm         <= '0';
			sha_start_session         <= '0';
			k_out_valid               <= '0';
			cipher_confirm_valid      <= '0';
			done                      <= '0';
			sha_hash_out_read_en      <= '0';
			sha_hash_out_read_confirm <= '0';
		elsif rising_edge(clock) then
			case state_enc_wrap is
				when idle =>
					if public_key_new = '1' and start_encap = '0' then
						state_enc_wrap           <= new_key;
						decode_Rq_start          <= '1';
						key_encap_new_public_key <= '1';
					end if;
					if public_key_new = '1' and start_encap = '1' then
						state_enc_wrap           <= new_key_and_encap;
						decode_Rq_start          <= '1';
						key_encap_new_public_key <= '1';
						key_encap_start_encap    <= '1';
						buffer_address_a         <= std_logic_vector(to_unsigned(p, p_num_bits));
					end if;
					ready                     <= '1';
					done                      <= '0';
					sha_hash_out_read_en      <= '0';
					sha_hash_out_read_confirm <= '0';
					k_out_valid               <= '0';
				when new_key_and_encap =>
					if key_encap_public_key_ready = '1' and key_encap_new_public_key /= '1' then
						state_enc_wrap    <= encap;
						public_key_is_set <= '1';
						sha_start_confirm <= '1';
					end if;
					decode_Rq_start          <= '0';
					key_encap_new_public_key <= '0';
					ready                    <= '0';

				when new_key =>
					if key_encap_public_key_ready = '1' and key_encap_new_public_key /= '1' then
						state_enc_wrap    <= key_ready;
						public_key_is_set <= '1';
					end if;
					decode_Rq_start          <= '0';
					key_encap_new_public_key <= '0';
					ready                    <= '0';

				when key_ready =>
					if start_encap = '1' and public_key_new = '0' then
						key_encap_start_encap <= '1';
						state_enc_wrap        <= encap;
						buffer_address_a      <= std_logic_vector(to_unsigned(p, p_num_bits));
						sha_start_confirm     <= '1';
					end if;
					if public_key_new = '1' and start_encap = '0' then
						state_enc_wrap           <= new_key;
						decode_Rq_start          <= '1';
						key_encap_new_public_key <= '1';
						public_key_is_set        <= '0';
					end if;
					if public_key_new = '1' and start_encap = '1' then
						state_enc_wrap           <= new_key_and_encap;
						buffer_address_a         <= std_logic_vector(to_unsigned(p, p_num_bits));
						decode_Rq_start          <= '1';
						key_encap_new_public_key <= '1';
						key_encap_start_encap    <= '1';
						public_key_is_set        <= '0';
					end if;
					ready                     <= '1';
					done                      <= '0';
					k_out_valid               <= '0';
					sha_hash_out_read_en      <= '0';
					sha_hash_out_read_confirm <= '0';
				when encap =>
					if key_encap_done = '1' then
						state_enc_wrap <= encap_done;
						address_b_var  <= 0;
					end if;

					key_encap_start_encap <= '0';
					ready                 <= '0';
					sha_start_confirm     <= '0';

					sha_start_session <= '1';

					if key_encap_c_encrypt_valid = '1' then
						buffer_address_a <= std_logic_vector(unsigned(buffer_address_a) - to_unsigned(1, p_num_bits));
					end if;
				when encap_done =>
					state_enc_wrap        <= encode_c;
					encode_Rq_input_valid <= '1';
					sha_start_session     <= '0';
				when encode_c =>
					if encode_Rq_input_ack = '1' then
						state_enc_wrap <= encode_c;
						address_b_var  <= address_b_var + 1;
					end if;

					if address_b_var = p then
						state_enc_wrap        <= encode_done;
						encode_Rq_input_valid <= '0';
					end if;
					sha_start_session <= '0';
				when encode_done =>
					if encode_Rq_done = '1' then
						state_enc_wrap  <= output_confirm;
						confirm_counter <= 0;
					end if;
					sha_hash_out_address      <= 0;
					sha_hash_out_read_en      <= '1';
					sha_hash_out_read_confirm <= '1';
				when output_confirm =>
					if confirm_counter /= 32 then
						cipher_confirm       <= sha_hash_out(63 - sha_hash_out_counter * 8 downto 64 - (sha_hash_out_counter + 1) * 8);
						cipher_confirm_valid <= '1';
						confirm_counter      <= confirm_counter + 1;

						if sha_hash_out_counter = 7 then
							sha_hash_out_counter <= 0;
						else
							sha_hash_out_counter <= sha_hash_out_counter + 1;
						end if;

						if sha_hash_out_counter = 6 then
							sha_hash_out_address <= sha_hash_out_address + 1;
						end if;

					else
						state_enc_wrap            <= wait_hash;
						cipher_confirm_valid      <= '0';
						sha_hash_out_read_confirm <= '0';
						sha_hash_out_address      <= 0;
						sha_hash_out_read_en      <= '0';
					end if;
				when wait_hash =>
					if sha_finished = '1' then
						state_enc_wrap       <= read_hash_out;
						sha_hash_out_read_en <= '1';
					end if;
				when read_hash_out =>
					state_enc_wrap <= done_state;
				when done_state =>
					sha_hash_out_read_en <= '1';
					sha_hash_out_address <= sha_hash_out_address + 1;
					k_out_valid          <= '1';

					if sha_hash_out_address = 3 then
						state_enc_wrap <= key_ready;
						done           <= '1';
					end if;

			end case;
		end if;
	end process fsm_process;

	k_hash_out <= sha_hash_out;

	decode_Rq_input       <= public_key_in;
	decode_Rq_input_valid <= public_key_valid when sha_ack_new_input = '1' else '0';

	public_key_in_ack <= decode_Rq_input_ack;

	decode_Rq_output_shift <= std_logic_vector(signed("0" & decode_Rq_output) - q12) when rising_edge(clock);

	key_encap_public_key_in <= decode_Rq_output_shift(q_num_bits - 1 downto 0);

	key_encap_public_key_valid <= decode_Rq_output_valid when rising_edge(clock);

	buffer_write_a   <= key_encap_c_encrypt_valid when rising_edge(clock);
	buffer_data_in_a <= key_encap_c_encrypt when rising_edge(clock);

	buffer_address_b <= std_logic_vector(to_unsigned(address_b_var, p_num_bits)) when encode_Rq_input_ack = '0' --
	                    else std_logic_vector(to_unsigned(address_b_var + 1, p_num_bits));

	encode_Rq_m_input <= std_logic_vector(to_unsigned((q + 2) / 3, 16));

	encode_Rq_input <= buffer_data_out_b;

	cipher_output       <= encode_Rq_output when state_enc_wrap /= output_confirm and state_enc_wrap /= done_state else cipher_confirm;
	cipher_output_valid <= encode_Rq_output_valid when state_enc_wrap /= output_confirm and state_enc_wrap /= done_state else cipher_confirm_valid;

	encode_Zx_input       <= key_encap_r_secret;
	encode_Zx_input_valid <= key_encap_r_secret_valid;

	sha_r_encoded_in       <= encode_Zx_output;
	sha_r_encoded_in_valid <= encode_Zx_output_valid;

	sha_c_encoded_in       <= encode_Rq_output;
	sha_c_encoded_in_valid <= encode_Rq_output_valid;

	to_encap_core.start_encap      <= key_encap_start_encap;
	to_encap_core.new_public_key   <= key_encap_new_public_key;
	to_encap_core.public_key_in    <= key_encap_public_key_in;
	to_encap_core.public_key_valid <= key_encap_public_key_valid;

	to_encap_core.small_weights_out   <= std_logic_vector(small_weights_out);
	to_encap_core.small_weights_valid <= small_weights_valid;
	to_encap_core.small_weights_done  <= small_weights_done;

	key_encap_ready <= from_encap_core.ready;
	key_encap_done  <= from_encap_core.done;

	key_encap_public_key_ready <= from_encap_core.public_key_ready;
	key_encap_c_encrypt        <= from_encap_core.c_encrypt;
	key_encap_c_encrypt_valid  <= from_encap_core.c_encrypt_valid;
	key_encap_r_secret         <= from_encap_core.r_secret;
	key_encap_r_secret_valid   <= from_encap_core.r_secret_valid;
	small_weights_start        <= from_encap_core.small_weights_start;

	to_small_weights.random_output <= small_weights_random_output;
	to_small_weights.start         <= small_weights_start;

	small_weights_done          <= from_small_weights.done;
	small_weights_random_enable <= from_small_weights.random_enable;
	small_weights_out           <= from_small_weights.small_weights_out;
	small_weights_valid         <= from_small_weights.small_weights_valid;

	to_decode_Rq.start          <= decode_Rq_start;
	to_decode_Rq.input          <= decode_Rq_input;
	to_decode_Rq.input_valid    <= decode_Rq_input_valid;
	decode_Rq_input_ack         <= from_decode_Rq.input_ack;
	to_decode_Rq.rounded_decode <= '0';
	decode_Rq_output            <= from_decode_Rq.output;
	decode_Rq_output_valid      <= from_decode_Rq.output_valid;
	decode_Rq_done              <= from_decode_Rq.done;

	to_encode_Rq.input       <= encode_Rq_input;
	to_encode_Rq.input_valid <= encode_Rq_input_valid;
	to_encode_Rq.m_input     <= encode_Rq_m_input;

	encode_Rq_input_ack    <= from_encode_Rq.input_ack;
	encode_Rq_output       <= from_encode_Rq.output;
	encode_Rq_output_valid <= from_encode_Rq.output_valid;
	encode_Rq_done         <= from_encode_Rq.done;

	encode_R3_inst : entity work.encode_R3
		port map(
			clock        => clock,
			reset        => reset,
			input        => encode_Zx_input,
			input_valid  => encode_Zx_input_valid,
			output       => encode_Zx_output,
			output_valid => encode_Zx_output_valid,
			done         => encode_Zx_done
		);

	block_ram_buffer : entity work.block_ram
		generic map(
			ADDRESS_WIDTH => p_num_bits,
			DATA_WIDTH    => q_num_bits
		)
		port map(
			clock      => clock,
			address_a  => buffer_address_a,
			write_a    => buffer_write_a,
			data_in_a  => buffer_data_in_a,
			data_out_a => open,
			address_b  => buffer_address_b,
			write_b    => '0',
			data_in_b  => (others => '0'),
			data_out_b => buffer_data_out_b
		);

	sha_record_in.new_public_key        <= public_key_new;
	sha_record_in.public_key_in         <= public_key_in;
	sha_record_in.public_key_ready      <= key_encap_public_key_ready;
	sha_record_in.new_pk_cache          <= '0';
	sha_record_in.pk_cache_in           <= (others => '0');
	sha_record_in.pk_cache_in_valid     <= '0';
	sha_record_in.start_confirm         <= sha_start_confirm;
	sha_record_in.r_encoded_in          <= sha_r_encoded_in;
	sha_record_in.r_encoded_in_valid    <= sha_r_encoded_in_valid;
	sha_record_in.start_session         <= sha_start_session;
	sha_record_in.re_encap_session      <= '0';
	sha_record_in.diff_mask             <= (others => '0');
	sha_record_in.c_encoded_in          <= sha_c_encoded_in;
	sha_record_in.c_encoded_in_valid    <= sha_c_encoded_in_valid;
	sha_record_in.decode_Rq_input_ack   <= decode_Rq_input_ack;
	sha_record_in.decode_Rq_input_valid <= decode_Rq_input_valid;
	sha_record_in.hash_out_address      <= std_logic_vector(to_unsigned(sha_hash_out_address, 2));
	sha_record_in.hash_out_read_en      <= sha_hash_out_read_en;
	sha_record_in.hash_out_read_pub_key <= '0';
	sha_record_in.hash_out_read_confirm <= sha_hash_out_read_confirm;

	sha_finished      <= sha_record_out.hash_finished;
	sha_ack_new_input <= sha_record_out.hash_ack_new_input;
	sha_hash_out      <= sha_record_out.hash_out;

	to_sha         <= sha_record_in;
	sha_record_out <= from_sha;

end architecture RTL;

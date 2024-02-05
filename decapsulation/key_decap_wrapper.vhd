library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.constants.all;
use work.data_type.all;

-- The wrapper for the core decapuslation. Constains en and decoding, and hashing and rencapsulation
entity key_decap_wrapper is
	port(
		clock              : in  std_logic;
		reset              : in  std_logic;
		secret_key_in      : in  std_logic_vector(7 downto 0);
		secret_key_valid   : in  std_logic;
		secret_key_in_ack  : out std_logic;
		key_new            : in  std_logic;
		key_is_set         : out std_logic;
		ready              : out std_logic;
		start_decap        : in  std_logic;
		cipher_input       : in  std_logic_vector(7 downto 0);
		cipher_input_valid : in  std_logic;
		cipher_input_ack   : out std_logic;
		k_hash_out         : out std_logic_vector(63 downto 0);
		k_out_valid        : out std_logic;
		done               : out std_logic;
		to_sha             : out sha_record_in_type;
		from_sha           : in  sha_record_out_type;
		to_decode_Rq       : out decode_Rq_in_type;
		from_decode_Rq     : in  decode_Rq_out_type;
		to_encode_Rq       : out encode_Rq_in_type;
		from_encode_Rq     : in  encode_Rq_out_type;
		to_encap_core      : out encap_core_in_type;
		from_encap_core    : in  encap_core_out_type;
		reencap_true       : out std_logic;
		to_rq_mult         : out rq_multiplication_in_type;
		from_rq_mult       : in  rq_multiplication_out_type;
		to_freeze_round    : out mod3_freeze_round_in_type;
		from_freeze_round  : in  mod3_freeze_round_out_type
	);
end entity key_decap_wrapper;

architecture RTL of key_decap_wrapper is

	type state_type is (IDLE, LOAD_NEW_KEY_F, LOAD_NEW_KEY_GINV, LOAD_NEW_KEY_PK, LOAD_RHO, LOAD_PK_CACHE, KEY_READY,
	                    LOAD_CIPHER, LOAD_CIPHER_HASH, LOAD_CIPHER_BRAM,
	                    DECAP_CORE_START, DECAP_CORE_RQ, DECAP_CORE_R3, DECAP_CORE_WAIT, REENCAP, REENCAP_END, REENCAP_ENCODE, REENCAP_DIF_HASH, REENCAP_ENCODE_DONE,
	                    MASK_R_ENC, MASK_R_ENC_DONE, HASH_SESSION_START, HASH_SESSION, HASH_SESSION_END, DONE_STATE
	                   );
	signal state_dec_wrap : state_type;

	signal key_decap_start                : std_logic;
	signal key_decap_done                 : std_logic;
	signal key_decap_r_output             : std_logic_vector(1 downto 0);
	signal key_decap_r_output_valid       : std_logic;
	signal key_decap_rq_mult_start        : std_logic;
	signal key_decap_rq_mult_ready        : std_logic;
	signal key_decap_rq_mult_output_valid : std_logic;
	signal key_decap_rq_mult_output       : std_logic_vector(q_num_bits - 1 downto 0);
	signal key_decap_rq_mult_output_ack   : std_logic;
	signal key_decap_rq_mult_done         : std_logic;
	signal key_decap_ginv_address_a       : std_logic_vector(p_num_bits - 1 downto 0);
	signal key_decap_ginv_data_out_a      : std_logic_vector(1 downto 0);
	signal key_decap_ginv_address_b       : std_logic_vector(p_num_bits - 1 downto 0);
	signal key_decap_ginv_data_out_b      : std_logic_vector(1 downto 0);

	signal key_encap_ready               : std_logic;
	signal key_encap_done                : std_logic;
	signal key_encap_start_encap         : std_logic;
	signal key_encap_new_public_key      : std_logic;
	signal key_encap_public_key_in       : std_logic_vector(q_num_bits - 1 downto 0);
	signal key_encap_public_key_valid    : std_logic;
	signal key_encap_public_key_ready    : std_logic;
	signal key_encap_c_encrypt           : std_logic_vector(q_num_bits - 1 downto 0);
	signal key_encap_c_encrypt_valid     : std_logic;
	signal key_encap_r_secret            : std_logic_vector(1 downto 0);
	signal key_encap_r_secret_valid      : std_logic;
	signal key_encap_small_weights_start : std_logic;
	signal key_encap_small_weights_out   : std_logic_vector(1 downto 0);
	signal key_encap_small_weights_valid : std_logic;
	signal key_encap_small_weights_done  : std_logic;

	signal key_encap_c_encrypt_valid_pipe : std_logic;

	signal bram_ginv_address_a  : std_logic_vector(p_num_bits - 1 downto 0);
	signal bram_ginv_write_a    : std_logic;
	signal bram_ginv_data_in_a  : std_logic_vector(1 downto 0);
	signal bram_ginv_data_out_a : std_logic_vector(1 downto 0);
	signal bram_ginv_address_b  : std_logic_vector(p_num_bits - 1 downto 0);
	signal bram_ginv_write_b    : std_logic;
	signal bram_ginv_data_in_b  : std_logic_vector(1 downto 0);
	signal bram_ginv_data_out_b : std_logic_vector(1 downto 0);

	signal bram_f_address_a  : std_logic_vector(p_num_bits - 1 downto 0);
	signal bram_f_write_a    : std_logic;
	signal bram_f_data_in_a  : std_logic_vector(1 downto 0);
	signal bram_f_data_out_a : std_logic_vector(1 downto 0);
	signal bram_f_address_b  : std_logic_vector(p_num_bits - 1 downto 0);
	signal bram_f_write_b    : std_logic;
	signal bram_f_data_in_b  : std_logic_vector(1 downto 0);
	signal bram_f_data_out_b : std_logic_vector(1 downto 0);

	signal bram_c_address_a  : std_logic_vector(p_num_bits - 1 downto 0);
	signal bram_c_write_a    : std_logic;
	signal bram_c_data_in_a  : std_logic_vector(q_num_bits - 1 downto 0);
	signal bram_c_data_out_a : std_logic_vector(q_num_bits - 1 downto 0);
	signal bram_c_address_b  : std_logic_vector(p_num_bits - 1 downto 0);
	signal bram_c_write_b    : std_logic;
	signal bram_c_data_in_b  : std_logic_vector(q_num_bits - 1 downto 0);
	signal bram_c_data_out_b : std_logic_vector(q_num_bits - 1 downto 0);

	signal rq_mult_start        : std_logic;
	signal rq_mult_ready        : std_logic;
	signal rq_mult_output_valid : std_logic;
	signal rq_mult_output       : std_logic_vector(q_num_bits - 1 downto 0);
	signal rq_mult_output_ack   : std_logic;
	signal rq_mult_done         : std_logic;
	signal rq_mult_f_address_a  : std_logic_vector(p_num_bits - 1 downto 0);
	signal rq_mult_f_data_out_a : std_logic_vector(q_num_bits - 1 downto 0);
	signal rq_mult_f_address_b  : std_logic_vector(p_num_bits - 1 downto 0);
	signal rq_mult_f_data_out_b : std_logic_vector(q_num_bits - 1 downto 0);
	signal rq_mult_g_address_a  : std_logic_vector(p_num_bits - 1 downto 0);
	signal rq_mult_g_data_out_a : std_logic_vector(1 downto 0);
	signal rq_mult_g_address_b  : std_logic_vector(p_num_bits - 1 downto 0);
	signal rq_mult_g_data_out_b : std_logic_vector(1 downto 0);

	signal decode_Rq_start        : std_logic;
	signal decode_Rq_input        : std_logic_vector(7 downto 0);
	signal decode_Rq_input_valid  : std_logic;
	signal decode_Rq_input_ack    : std_logic;
	signal decode_rounded_true    : std_logic;
	signal decode_Rq_output       : std_logic_vector(q_num_bits - 1 downto 0);
	signal decode_Rq_output_valid : std_logic;
	signal decode_Rq_done         : std_logic;

	signal decode_Zx_input        : std_logic_vector(7 downto 0);
	signal decode_Zx_input_valid  : std_logic;
	signal decode_Zx_input_ack    : std_logic;
	signal decode_Zx_output       : std_logic_vector(1 downto 0);
	signal decode_Zx_output_valid : std_logic;
	signal decode_Zx_done         : std_logic;

	signal counter        : integer range 0 to 2047;
	signal counter_c_diff : integer range 0 to 2047;

	signal counter_pipe : integer range 0 to 2047;

	signal bram_pk_address_a  : std_logic_vector(p_num_bits - 1 downto 0);
	signal bram_pk_write_a    : std_logic;
	signal bram_pk_data_in_a  : std_logic_vector(q_num_bits - 1 downto 0);
	signal bram_pk_data_out_a : std_logic_vector(q_num_bits - 1 downto 0);
	signal bram_pk_address_b  : std_logic_vector(p_num_bits - 1 downto 0);
	signal bram_pk_write_b    : std_logic;
	signal bram_pk_data_in_b  : std_logic_vector(q_num_bits - 1 downto 0);
	signal bram_pk_data_out_b : std_logic_vector(q_num_bits - 1 downto 0);

	signal bram_rho_address_a  : std_logic_vector(Small_bytes_bits - 1 downto 0);
	signal bram_rho_write_a    : std_logic;
	signal bram_rho_data_in_a  : std_logic_vector(7 downto 0);
	signal bram_rho_data_out_a : std_logic_vector(7 downto 0);

	signal sha_start_confirm         : std_logic;
	signal sha_r_encoded_in          : std_logic_vector(7 downto 0);
	signal sha_r_encoded_in_valid    : std_logic;
	signal sha_start_session         : std_logic;
	signal sha_c_encoded_in          : std_logic_vector(7 downto 0);
	signal sha_c_encoded_in_valid    : std_logic;
	signal sha_decode_Rq_input_ack   : std_logic;
	signal sha_decode_Rq_input_valid : std_logic;
	signal sha_finished          : std_logic;
	signal sha_ack_new_input         : std_logic;
	signal sha_out          : std_logic_vector(63 downto 0);
	signal sha_out_address      : integer range 0 to 3;
	signal sha_out_read_en      : std_logic;
	signal sha_new_pk_cache          : std_logic;
	signal sha_pk_cache_in           : std_logic_vector(7 downto 0);
	signal sha_pk_cache_in_valid     : std_logic;
	signal sha_re_encap_session      : std_logic;
	signal sha_diff_mask             : std_logic_vector(7 downto 0);

	signal encode_Zx_input        : std_logic_vector(1 downto 0);
	signal encode_Zx_input_valid  : std_logic;
	signal encode_Zx_output       : std_logic_vector(7 downto 0);
	signal encode_Zx_output_valid : std_logic;
	signal encode_Zx_done         : std_logic;

	signal encode_Rq_input        : std_logic_vector(q_num_bits - 1 downto 0);
	signal encode_Rq_input_valid  : std_logic;
	signal encode_Rq_m_input      : std_logic_vector(15 downto 0);
	signal encode_Rq_input_ack    : std_logic;
	signal encode_Rq_output       : std_logic_vector(7 downto 0);
	signal encode_Rq_output_valid : std_logic;
	signal encode_Rq_done         : std_logic;

	signal bram_c_diff_address_a  : std_logic_vector(Cipher_bytes_bits - 1 downto 0);
	signal bram_c_diff_write_a    : std_logic;
	signal bram_c_diff_data_in_a  : std_logic_vector(7 downto 0);
	signal bram_c_diff_data_out_a : std_logic_vector(7 downto 0);

	signal differentbits : std_logic_vector(15 downto 0);

	signal bram_r_enc_address_a  : std_logic_vector(Small_bytes_bits - 1 downto 0);
	signal bram_r_enc_write_a    : std_logic;
	signal bram_r_enc_data_in_a  : std_logic_vector(7 downto 0);
	signal bram_r_enc_data_out_a : std_logic_vector(7 downto 0);

	signal masked_r_enc       : std_logic_vector(7 downto 0);
	signal masked_r_enc_valid : std_logic;

	signal c_diff_bram_valid : std_logic;

	signal temp_s : std_logic_vector(7 downto 0);

	signal sha_record_in  : sha_record_in_type;
	signal sha_record_out : sha_record_out_type;

	signal key_decap_to_r3_mult   : rq_multiplication_in_type;
	signal key_decap_from_r3_mult : rq_multiplication_out_type;

	signal sha_out_counter : integer range 0 to 8;

begin

	decap_wrapper_process : process(clock, reset) is
	begin
		if reset = '1' then
			state_dec_wrap        <= IDLE;
			ready                 <= '0';
			key_is_set            <= '0';
			decode_Rq_start       <= '0';
			key_decap_start       <= '0';
			key_encap_start_encap <= '0';
			sha_new_pk_cache      <= '0';
			sha_start_confirm     <= '0';
			sha_start_session     <= '0';
			sha_re_encap_session  <= '0';
			encode_Rq_input_valid <= '0';
			masked_r_enc_valid    <= '0';
			c_diff_bram_valid     <= '0';
			done                  <= '0';
			k_out_valid           <= '0';
			sha_out_read_en  <= '0';
		elsif rising_edge(clock) then
			case state_dec_wrap is
				when IDLE =>
					if key_new = '1' then
						state_dec_wrap <= LOAD_NEW_KEY_F;

						decode_rounded_true <= '0';
						counter             <= 0;
					end if;

					ready                <= '1';
					done                 <= '0';
					k_out_valid          <= '0';
					sha_out_read_en <= '0';
					sha_out_counter <= 0;
				when LOAD_NEW_KEY_F =>
					if decode_Zx_done = '1' then
						state_dec_wrap <= LOAD_NEW_KEY_GINV;
						counter        <= 0;
					end if;

					ready <= '0';

					if decode_Zx_output_valid = '1' and decode_Zx_done = '0' then
						counter <= counter + 1;
					end if;

				when LOAD_NEW_KEY_GINV =>
					if decode_Zx_done = '1' then
						state_dec_wrap  <= LOAD_NEW_KEY_PK;
						decode_Rq_start <= '1';
						counter         <= 0;
					end if;

					if decode_Zx_output_valid = '1' and decode_Zx_done = '0' then
						counter <= counter + 1;
					end if;
				when LOAD_NEW_KEY_PK =>
					if decode_Rq_done = '1' then
						state_dec_wrap   <= LOAD_RHO;
						counter          <= 0;
						sha_new_pk_cache <= '1';
					end if;

					if decode_Rq_output_valid = '1' and decode_Rq_done = '0' then
						counter <= counter + 1;
					end if;
					decode_Rq_start <= '0';
				when LOAD_RHO =>
					if secret_key_valid = '1' then
						counter <= counter + 1;
					end if;

					if counter = Small_bytes - 1 then
						state_dec_wrap <= LOAD_PK_CACHE;
						counter        <= 0;
					end if;
					sha_new_pk_cache <= '0';
				when LOAD_PK_CACHE =>
					if secret_key_valid = '1' then
						counter <= counter + 1;
					end if;

					if counter = 31 then
						state_dec_wrap <= KEY_READY;
						counter        <= 0;
					end if;

				when KEY_READY =>
					ready      <= '1';
					key_is_set <= '1';

					if start_decap = '1' then
						state_dec_wrap      <= LOAD_CIPHER;
						decode_Rq_start     <= '1';
						decode_rounded_true <= '1';
						counter_c_diff      <= 0;
						ready               <= '0';
					end if;

					if key_new = '1' then
						ready               <= '0';
						key_is_set          <= '0';
						state_dec_wrap      <= LOAD_NEW_KEY_F;
						decode_rounded_true <= '0';
						counter             <= 0;
					end if;

					done                 <= '0';
					k_out_valid          <= '0';
					sha_out_read_en <= '0';
					sha_out_counter <= 0;
				when LOAD_CIPHER =>
					decode_Rq_start <= '0';
					if cipher_input_valid = '1' and decode_Rq_input_ack = '1' then
						counter_c_diff <= counter_c_diff + 1;
						if counter_c_diff = Ciphertexts_bytes - 1 then
							state_dec_wrap <= LOAD_CIPHER_HASH;
						end if;
					end if;

				when LOAD_CIPHER_HASH =>
					if cipher_input_valid = '1' then
						counter_c_diff <= counter_c_diff + 1;
					end if;
					if counter_c_diff = Ciphertexts_bytes + 32 - 1 then
						state_dec_wrap <= LOAD_CIPHER_BRAM;
						counter        <= 0;
						counter_c_diff <= 0;
					end if;
				when LOAD_CIPHER_BRAM =>
					if decode_Rq_output_valid = '1' then
						counter <= counter + 1;
					end if;
					if decode_Rq_done = '1' then
						state_dec_wrap <= DECAP_CORE_START;
					end if;
				when DECAP_CORE_START =>
					state_dec_wrap        <= DECAP_CORE_RQ;
					key_decap_start       <= '1';
					key_encap_start_encap <= '1';
					sha_start_confirm     <= '1';
					counter               <= 0;
				when DECAP_CORE_RQ =>
					if rq_mult_done = '1' then
						state_dec_wrap <= DECAP_CORE_R3;
					end if;

					key_decap_start       <= '0';
					key_encap_start_encap <= '0';
					sha_start_confirm     <= '0';
				when DECAP_CORE_R3 =>
					if key_decap_from_r3_mult.done = '1' then
						state_dec_wrap <= DECAP_CORE_WAIT;
					end if;
					if encode_Zx_output_valid = '1' then
						counter <= counter + 1;
					end if;
				when DECAP_CORE_WAIT =>
					if key_decap_done = '1' then
						state_dec_wrap <= REENCAP;
						counter        <= p - 1;
					end if;

					key_decap_start       <= '0';
					key_encap_start_encap <= '0';
					sha_start_confirm     <= '0';

					if encode_Zx_output_valid = '1' then
						counter <= counter + 1;
					end if;

				when REENCAP =>
					if key_encap_c_encrypt_valid = '1' and counter /= 0 then
						counter <= counter - 1;
					end if;

					if key_encap_done = '1' then
						state_dec_wrap <= REENCAP_END;
						counter        <= 0;
					end if;
				when REENCAP_END =>
					state_dec_wrap        <= REENCAP_ENCODE;
					encode_Rq_input_valid <= '1';
					counter_c_diff        <= 0;
					differentbits         <= (others => '0');
				when REENCAP_ENCODE =>
					if encode_Rq_input_ack = '1' and counter /= p - 1 then
						counter <= counter + 1;
					end if;

					if counter = p - 1 then
						encode_Rq_input_valid <= '0';
					end if;

					if encode_Rq_done = '1' then
						state_dec_wrap <= REENCAP_DIF_HASH;
						temp_s         <= sha_out(63 - sha_out_counter * 8 downto 64 - (sha_out_counter + 1) * 8);
					end if;

					sha_start_session    <= '0';
					sha_out_address <= 0;
					sha_out_read_en <= '1';

					if encode_Rq_output_valid = '1' then
						counter_c_diff            <= counter_c_diff + 1;
						differentbits(7 downto 0) <= differentbits(7 downto 0) OR (encode_Rq_output XOR bram_c_diff_data_out_a);
					end if;
				when REENCAP_DIF_HASH =>
					if counter_c_diff = Ciphertexts_bytes + 32 - 1 then
						state_dec_wrap       <= REENCAP_ENCODE_DONE;
						sha_out_read_en <= '0';
					end if;
					counter_c_diff            <= counter_c_diff + 1;
					temp_s                    <= sha_out(63 - sha_out_counter * 8 downto 64 - (sha_out_counter + 1) * 8);
					differentbits(7 downto 0) <= differentbits(7 downto 0) OR (temp_s XOR bram_c_diff_data_out_a);

					if sha_out_counter = 7 then
						sha_out_counter <= 0;
					else
						sha_out_counter <= sha_out_counter + 1;
					end if;

					if sha_out_counter = 6 then
						if sha_out_address = 3 then
							sha_out_address <= 0;
						else
							sha_out_address <= sha_out_address + 1;
						end if;
					end if;
				when REENCAP_ENCODE_DONE =>
					differentbits     <= std_logic_vector(("0000000000000001" AND shift_right(signed(differentbits(15 downto 8) & (differentbits(7 downto 0) OR (temp_s XOR bram_c_diff_data_out_a))) - 1, 8)) - 1);
					state_dec_wrap    <= MASK_R_ENC;
					counter           <= 0;
					sha_start_confirm <= '1';
				when MASK_R_ENC =>
					if counter = Small_bytes then
						state_dec_wrap <= MASK_R_ENC_DONE;
					end if;
					sha_start_confirm <= '0';

					if sha_ack_new_input = '1' then
						counter <= counter + 1;

					end if;
					masked_r_enc_valid <= '1';
				when MASK_R_ENC_DONE =>
					masked_r_enc_valid <= '0';
					if sha_finished = '1' then
						state_dec_wrap       <= HASH_SESSION_START;
						sha_start_session    <= '1';
						sha_re_encap_session <= '1';
						counter_c_diff       <= 0;
					end if;
				when HASH_SESSION_START =>
					state_dec_wrap    <= HASH_SESSION;
					sha_start_session <= '0';
				when HASH_SESSION =>

					if counter_c_diff = Ciphertexts_bytes + 32 - 1 then
						state_dec_wrap <= HASH_SESSION_END;
					end if;

					if sha_ack_new_input = '1' then
						counter_c_diff    <= counter_c_diff + 1;
						c_diff_bram_valid <= '1';
					else
						c_diff_bram_valid <= '0';
						if c_diff_bram_valid = '1' and sha_ack_new_input = '0' then
							counter_c_diff <= counter_c_diff - 1;
						end if;

					end if;

				when HASH_SESSION_END =>
					c_diff_bram_valid <= '0';
					if sha_finished = '1' then
						state_dec_wrap       <= DONE_STATE;
						sha_re_encap_session <= '0';
						sha_out_read_en <= '1';
						sha_out_address <= 0;
					end if;
				when DONE_STATE =>
					if sha_out_address = 3 then
						done           <= '1';
						state_dec_wrap <= KEY_READY;
					else
						sha_out_address <= sha_out_address + 1;
					end if;
					k_out_valid          <= '1';
			end case;
		end if;
	end process decap_wrapper_process;

	decode_Zx_input       <= secret_key_in when state_dec_wrap = LOAD_NEW_KEY_F or state_dec_wrap = LOAD_NEW_KEY_GINV else (others => '0');
	decode_Zx_input_valid <= secret_key_valid when state_dec_wrap = LOAD_NEW_KEY_F or state_dec_wrap = LOAD_NEW_KEY_GINV else '0';
	secret_key_in_ack     <= secret_key_valid when state_dec_wrap = LOAD_RHO or state_dec_wrap = LOAD_PK_CACHE
	                         else decode_Rq_input_ack when state_dec_wrap = LOAD_NEW_KEY_PK
	                         else decode_Zx_input_ack;

	decode_Rq_input       <= secret_key_in when state_dec_wrap = LOAD_NEW_KEY_PK else cipher_input;
	decode_Rq_input_valid <= secret_key_valid when state_dec_wrap = LOAD_NEW_KEY_PK
	                         else cipher_input_valid when state_dec_wrap = LOAD_CIPHER
	                         else '0';

	cipher_input_ack <= decode_Rq_input_ack when state_dec_wrap = LOAD_CIPHER
	                    else '1' when state_dec_wrap = LOAD_CIPHER_HASH
	                    else '0';

	bram_pk_address_a <= std_logic_vector(to_unsigned(counter, p_num_bits));
	bram_pk_data_in_a <= std_logic_vector(signed(decode_Rq_output) - q12);
	bram_pk_write_a   <= decode_Rq_output_valid when state_dec_wrap = LOAD_NEW_KEY_PK else '0';

	bram_f_address_a     <= std_logic_vector(to_unsigned(counter, p_num_bits)) when state_dec_wrap = LOAD_NEW_KEY_F else rq_mult_g_address_a;
	bram_f_data_in_a     <= decode_Zx_output;
	bram_f_write_a       <= decode_Zx_output_valid when state_dec_wrap = LOAD_NEW_KEY_F else '0';
	rq_mult_g_data_out_a <= bram_f_data_out_a;

	bram_f_address_b     <= rq_mult_g_address_b;
	rq_mult_g_data_out_b <= bram_f_data_out_b;

	bram_ginv_address_a       <= std_logic_vector(to_unsigned(counter, p_num_bits)) when state_dec_wrap = LOAD_NEW_KEY_GINV else key_decap_ginv_address_a;
	bram_ginv_data_in_a       <= decode_Zx_output;
	bram_ginv_write_a         <= decode_Zx_output_valid when state_dec_wrap = LOAD_NEW_KEY_GINV else '0';
	key_decap_ginv_data_out_a <= bram_ginv_data_out_a;

	bram_ginv_address_b       <= key_decap_ginv_address_b;
	key_decap_ginv_data_out_b <= bram_ginv_data_out_b;

	bram_c_address_a     <= std_logic_vector(to_unsigned(counter, p_num_bits)) when state_dec_wrap = LOAD_CIPHER_BRAM else rq_mult_f_address_a;
	bram_c_data_in_a     <= std_logic_vector(resize(signed(decode_Rq_output) * 3 - q12, q_num_bits));
	bram_c_write_a       <= decode_Rq_output_valid when state_dec_wrap = LOAD_CIPHER_BRAM else '0';
	rq_mult_f_data_out_a <= bram_c_data_out_a;

	counter_pipe <= counter when rising_edge(clock);

	bram_c_address_b <= rq_mult_f_address_b when state_dec_wrap = DECAP_CORE_WAIT or state_dec_wrap = DECAP_CORE_RQ or state_dec_wrap = DECAP_CORE_RQ
	                    else std_logic_vector(to_unsigned(counter_pipe, p_num_bits)) when state_dec_wrap = REENCAP
	                    else std_logic_vector(to_unsigned(counter, p_num_bits)) when encode_Rq_input_ack = '0'
	                    else std_logic_vector(to_unsigned(counter + 1, p_num_bits));

	key_encap_c_encrypt_valid_pipe <= key_encap_c_encrypt_valid when rising_edge(clock);
	bram_c_write_b                 <= key_encap_c_encrypt_valid_pipe when state_dec_wrap = REENCAP else '0';
	bram_c_data_in_b               <= key_encap_c_encrypt when rising_edge(clock);

	rq_mult_f_data_out_b <= bram_c_data_out_b;

	rq_mult_start                  <= key_decap_rq_mult_start;
	key_decap_rq_mult_ready        <= rq_mult_ready;
	key_decap_rq_mult_output_valid <= rq_mult_output_valid;
	key_decap_rq_mult_output       <= rq_mult_output;
	rq_mult_output_ack             <= key_decap_rq_mult_output_ack;
	key_decap_rq_mult_done         <= rq_mult_done;

	key_encap_new_public_key   <= key_new;
	key_encap_public_key_in    <= bram_pk_data_in_a;
	key_encap_public_key_valid <= decode_Rq_output_valid when state_dec_wrap = LOAD_NEW_KEY_PK else '0';

	key_encap_small_weights_out   <= key_decap_r_output;
	key_encap_small_weights_valid <= key_decap_r_output_valid;
	key_encap_small_weights_done  <= key_decap_done;

	bram_rho_address_a <= std_logic_vector(to_unsigned(counter, Small_bytes_bits));
	bram_rho_data_in_a <= secret_key_in;
	bram_rho_write_a   <= secret_key_valid when state_dec_wrap = LOAD_RHO else '0';

	sha_pk_cache_in       <= secret_key_in;
	sha_pk_cache_in_valid <= secret_key_valid when state_dec_wrap = LOAD_PK_CACHE else '0';

	encode_Zx_input       <= key_encap_r_secret;
	encode_Zx_input_valid <= key_encap_r_secret_valid;

	masked_r_enc <= bram_r_enc_data_out_a XOR (differentbits(7 downto 0) AND (bram_r_enc_data_out_a XOR bram_rho_data_out_a));

	sha_r_encoded_in       <= masked_r_enc when state_dec_wrap = MASK_R_ENC else encode_Zx_output;
	sha_r_encoded_in_valid <= masked_r_enc_valid when state_dec_wrap = MASK_R_ENC else encode_Zx_output_valid;

	sha_c_encoded_in       <= bram_c_diff_data_out_a;
	sha_c_encoded_in_valid <= c_diff_bram_valid when sha_ack_new_input = '1' else '0';

	sha_diff_mask <= differentbits(7 downto 0);

	encode_Rq_m_input <= std_logic_vector(to_unsigned((q + 2) / 3, 16));
	encode_Rq_input   <= bram_c_data_out_b;

	bram_c_diff_address_a <= std_logic_vector(to_signed(counter_c_diff - 1, Cipher_bytes_bits+1)(Cipher_bytes_bits-1 downto 0)) when sha_ack_new_input = '0' and state_dec_wrap = HASH_SESSION
	                         else std_logic_vector(to_unsigned(counter_c_diff, Cipher_bytes_bits)) when encode_Rq_output_valid = '0' --
	                         else std_logic_vector(to_unsigned(counter_c_diff + 1, Cipher_bytes_bits));

	bram_c_diff_data_in_a <= cipher_input;
	bram_c_diff_write_a   <= cipher_input_valid when (state_dec_wrap = LOAD_CIPHER and decode_Rq_input_ack = '1') or state_dec_wrap = LOAD_CIPHER_HASH else '0';

	bram_r_enc_address_a <= std_logic_vector(to_unsigned(counter, Small_bytes_bits));
	bram_r_enc_data_in_a <= encode_Zx_output;
	bram_r_enc_write_a   <= encode_Zx_output_valid when state_dec_wrap = DECAP_CORE_WAIT else '0';

	k_hash_out(63 downto 0) <= sha_out;

	key_decapsulation_inst : entity work.key_decapsulation
		port map(
			clock                => clock,
			reset                => reset,
			start                => key_decap_start,
			done                 => key_decap_done,
			output               => key_decap_r_output,
			output_valid         => key_decap_r_output_valid,
			rq_mult_start        => key_decap_rq_mult_start,
			rq_mult_ready        => key_decap_rq_mult_ready,
			rq_mult_output_valid => key_decap_rq_mult_output_valid,
			rq_mult_output       => key_decap_rq_mult_output,
			rq_mult_output_ack   => key_decap_rq_mult_output_ack,
			rq_mult_done         => key_decap_rq_mult_done,
			bram_ginv_address_a  => key_decap_ginv_address_a,
			bram_ginv_data_out_a => key_decap_ginv_data_out_a,
			bram_ginv_address_b  => key_decap_ginv_address_b,
			bram_ginv_data_out_b => key_decap_ginv_data_out_b,
			to_r3_mult           => key_decap_to_r3_mult,
			from_r3_mult         => key_decap_from_r3_mult,
			to_freeze_round      => to_freeze_round,
			from_freeze_round    => from_freeze_round
		);

	to_encap_core.start_encap      <= key_encap_start_encap;
	to_encap_core.new_public_key   <= key_encap_new_public_key;
	to_encap_core.public_key_in    <= key_encap_public_key_in;
	to_encap_core.public_key_valid <= key_encap_public_key_valid;

	to_encap_core.small_weights_out   <= key_encap_small_weights_out;
	to_encap_core.small_weights_valid <= key_encap_small_weights_valid;
	to_encap_core.small_weights_done  <= key_encap_small_weights_done;

	key_encap_ready <= from_encap_core.ready;
	key_encap_done  <= from_encap_core.done;

	key_encap_public_key_ready    <= from_encap_core.public_key_ready;
	key_encap_c_encrypt           <= from_encap_core.c_encrypt;
	key_encap_c_encrypt_valid     <= from_encap_core.c_encrypt_valid;
	key_encap_r_secret            <= from_encap_core.r_secret;
	key_encap_r_secret_valid      <= from_encap_core.r_secret_valid;
	key_encap_small_weights_start <= from_encap_core.small_weights_start;

	reencap_true <= '1' when state_dec_wrap = REENCAP else '0';

	to_rq_mult.start             <= rq_mult_start when state_dec_wrap /= DECAP_CORE_R3 else key_decap_to_r3_mult.start;
	to_rq_mult.output_ack        <= rq_mult_output_ack when state_dec_wrap /= DECAP_CORE_R3 else key_decap_to_r3_mult.output_ack;
	to_rq_mult.bram_f_data_out_a <= rq_mult_f_data_out_a when state_dec_wrap /= DECAP_CORE_R3 else key_decap_to_r3_mult.bram_f_data_out_a;
	to_rq_mult.bram_f_data_out_b <= rq_mult_f_data_out_b when state_dec_wrap /= DECAP_CORE_R3 else key_decap_to_r3_mult.bram_f_data_out_b;
	to_rq_mult.bram_g_data_out_a <= rq_mult_g_data_out_a when state_dec_wrap /= DECAP_CORE_R3 else key_decap_to_r3_mult.bram_g_data_out_a;
	to_rq_mult.bram_g_data_out_b <= rq_mult_g_data_out_b when state_dec_wrap /= DECAP_CORE_R3 else key_decap_to_r3_mult.bram_g_data_out_b;
	rq_mult_ready                <= from_rq_mult.ready;
	rq_mult_output_valid         <= from_rq_mult.output_valid;
	rq_mult_output               <= from_rq_mult.output;
	rq_mult_done                 <= from_rq_mult.done;

	key_decap_from_r3_mult.ready        <= from_rq_mult.ready;
	key_decap_from_r3_mult.output_valid <= from_rq_mult.output_valid;
	key_decap_from_r3_mult.output       <= from_rq_mult.output;
	key_decap_from_r3_mult.done         <= from_rq_mult.done;

	rq_mult_f_address_a <= from_rq_mult.bram_f_address_a;
	rq_mult_f_address_b <= from_rq_mult.bram_f_address_b;
	rq_mult_g_address_a <= from_rq_mult.bram_g_address_a;
	rq_mult_g_address_b <= from_rq_mult.bram_g_address_b;

	key_decap_from_r3_mult.bram_f_address_a <= from_rq_mult.bram_f_address_a;
	key_decap_from_r3_mult.bram_f_address_b <= from_rq_mult.bram_f_address_b;
	key_decap_from_r3_mult.bram_g_address_a <= from_rq_mult.bram_g_address_a;
	key_decap_from_r3_mult.bram_g_address_b <= from_rq_mult.bram_g_address_b;

	sha_record_in.new_public_key        <= '0';
	sha_record_in.public_key_in         <= (others => '0');
	sha_record_in.public_key_ready      <= '0';
	sha_record_in.new_pk_cache          <= sha_new_pk_cache;
	sha_record_in.pk_cache_in           <= sha_pk_cache_in;
	sha_record_in.pk_cache_in_valid     <= sha_pk_cache_in_valid;
	sha_record_in.start_confirm         <= sha_start_confirm;
	sha_record_in.r_encoded_in          <= sha_r_encoded_in;
	sha_record_in.r_encoded_in_valid    <= sha_r_encoded_in_valid;
	sha_record_in.start_session         <= sha_start_session;
	sha_record_in.re_encap_session      <= sha_re_encap_session;
	sha_record_in.diff_mask             <= sha_diff_mask;
	sha_record_in.c_encoded_in          <= sha_c_encoded_in;
	sha_record_in.c_encoded_in_valid    <= sha_c_encoded_in_valid;
	sha_record_in.decode_Rq_input_ack   <= decode_Rq_input_ack;
	sha_record_in.decode_Rq_input_valid <= decode_Rq_input_valid;
	sha_record_in.hash_out_address      <= std_logic_vector(to_unsigned(sha_out_address, 2));
	sha_record_in.hash_out_read_en      <= sha_out_read_en;
	sha_record_in.hash_out_read_pub_key <= '0';
	sha_record_in.hash_out_read_confirm <= '1' when state_dec_wrap /= HASH_SESSION_END and state_dec_wrap /= DONE_STATE else '0';

	sha_finished  <= sha_record_out.hash_finished;
	sha_ack_new_input <= sha_record_out.hash_ack_new_input;
	sha_out  <= sha_record_out.hash_out;

	to_sha         <= sha_record_in;
	sha_record_out <= from_sha;

	to_decode_Rq.start          <= decode_Rq_start;
	to_decode_Rq.input          <= decode_Rq_input;
	to_decode_Rq.input_valid    <= decode_Rq_input_valid;
	decode_Rq_input_ack         <= from_decode_Rq.input_ack;
	to_decode_Rq.rounded_decode <= decode_rounded_true;
	decode_Rq_output            <= from_decode_Rq.output;
	decode_Rq_output_valid      <= from_decode_Rq.output_valid;
	decode_Rq_done              <= from_decode_Rq.done;

	decode_R3_inst : entity work.decode_R3
		port map(
			clock        => clock,
			reset        => reset,
			input        => decode_Zx_input,
			input_valid  => decode_Zx_input_valid,
			input_ack    => decode_Zx_input_ack,
			output       => decode_Zx_output,
			output_valid => decode_Zx_output_valid,
			done         => decode_Zx_done
		);

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

	bram_f_write_b <= '0';

	block_ram_inst_f : entity work.block_ram
		generic map(
			ADDRESS_WIDTH => p_num_bits,
			DATA_WIDTH    => 2
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

	bram_ginv_write_b <= '0';

	block_ram_inst_ginv : entity work.block_ram
		generic map(
			ADDRESS_WIDTH => p_num_bits,
			DATA_WIDTH    => 2
		)
		port map(
			clock      => clock,
			address_a  => bram_ginv_address_a,
			write_a    => bram_ginv_write_a,
			data_in_a  => bram_ginv_data_in_a,
			data_out_a => bram_ginv_data_out_a,
			address_b  => bram_ginv_address_b,
			write_b    => bram_ginv_write_b,
			data_in_b  => bram_ginv_data_in_b,
			data_out_b => bram_ginv_data_out_b
		);
	block_ram_inst_c : entity work.block_ram
		generic map(
			ADDRESS_WIDTH => p_num_bits,
			DATA_WIDTH    => q_num_bits
		)
		port map(
			clock      => clock,
			address_a  => bram_c_address_a,
			write_a    => bram_c_write_a,
			data_in_a  => bram_c_data_in_a,
			data_out_a => bram_c_data_out_a,
			address_b  => bram_c_address_b,
			write_b    => bram_c_write_b,
			data_in_b  => bram_c_data_in_b,
			data_out_b => bram_c_data_out_b
		);

	block_ram_inst_pk : entity work.block_ram
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

	block_ram_inst_rand_reject : entity work.block_ram
		generic map(
			ADDRESS_WIDTH => Small_bytes_bits,
			DATA_WIDTH    => 8,
			DUAL_PORT     => FALSE
		)
		port map(
			clock      => clock,
			address_a  => bram_rho_address_a,
			write_a    => bram_rho_write_a,
			data_in_a  => bram_rho_data_in_a,
			data_out_a => bram_rho_data_out_a,
			address_b  => (others => '0'),
			write_b    => '0',
			data_in_b  => (others => '0'),
			data_out_b => open
		);

	block_ram_inst_c_diff : entity work.block_ram
		generic map(
			ADDRESS_WIDTH => Cipher_bytes_bits,
			DATA_WIDTH    => 8,
			DUAL_PORT     => FALSE
		)
		port map(
			clock      => clock,
			address_a  => bram_c_diff_address_a,
			write_a    => bram_c_diff_write_a,
			data_in_a  => bram_c_diff_data_in_a,
			data_out_a => bram_c_diff_data_out_a,
			address_b  => (others => '0'),
			write_b    => '0',
			data_in_b  => (others => '0'),
			data_out_b => open
		);

	block_ram_inst_r_enc : entity work.block_ram
		generic map(
			ADDRESS_WIDTH => Small_bytes_bits,
			DATA_WIDTH    => 8,
			DUAL_PORT     => FALSE
		)
		port map(
			clock      => clock,
			address_a  => bram_r_enc_address_a,
			write_a    => bram_r_enc_write_a,
			data_in_a  => bram_r_enc_data_in_a,
			data_out_a => bram_r_enc_data_out_a,
			address_b  => (others => '0'),
			write_b    => '0',
			data_in_b  => (others => '0'),
			data_out_b => open
		);

end architecture RTL;

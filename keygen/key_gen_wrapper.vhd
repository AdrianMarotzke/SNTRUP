library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.constants.all;
use work.data_type.all;

-- Wrapper for the core key generation, adds encoding, hashing
entity key_gen_wrapper is
	port(
		clock                  : in  std_logic;
		reset                  : in  std_logic;
		start                  : in  std_logic;
		ready                  : out std_logic;
		done                   : out std_logic;
		encoded_pk             : out std_logic_vector(7 downto 0);
		encoded_pk_valid       : out std_logic;
		private_key_out        : out std_logic_vector(7 downto 0);
		private_key_out_valid  : out std_logic;
		random_small_enable    : out std_logic;
		random_small_poly      : in  std_logic_vector(1 downto 0);
		random_enable          : out std_logic;
		random_output          : in  std_logic_vector(31 downto 0);
		to_sha                 : out sha_record_in_type;
		from_sha               : in  sha_record_out_type;
		to_encode_Rq           : out encode_Rq_in_type;
		from_encode_Rq         : in  encode_Rq_out_type;
		to_rq_mult             : out rq_multiplication_in_type;
		from_rq_mult           : in  rq_multiplication_out_type;
		to_small_weights       : out small_random_weights_in_type;
		from_small_weights     : in  small_random_weights_out_type
	);
end entity key_gen_wrapper;

architecture RTL of key_gen_wrapper is
	signal output_h       : std_logic_vector(q_num_bits - 1 downto 0);
	signal output_h_valid : std_logic;
	signal output_f       : std_logic_vector(1 downto 0);
	signal output_f_valid : std_logic;
	signal output_g_recip : std_logic_vector(1 downto 0);
	signal output_g_valid : std_logic;

	signal done_pk      : std_logic;
	signal done_f       : std_logic;
	signal done_g       : std_logic;
	signal done_key_gen : std_logic;

	signal output_h_ack : std_logic;

	signal buffer_address_a       : std_logic_vector(p_num_bits - 1 downto 0);
	signal buffer_write_a         : std_logic;
	signal buffer_data_in_a       : std_logic_vector(q_num_bits - 1 downto 0);
	signal buffer_data_in_a_shift : std_logic_vector(q_num_bits downto 0);
	signal buffer_address_b       : std_logic_vector(p_num_bits - 1 downto 0);
	signal buffer_data_out_b      : std_logic_vector(q_num_bits - 1 downto 0);

	signal address_b_var         : integer range 0 to p;
	signal output_h_valid_buffer : std_logic;
	signal encoder_input_valid   : std_logic;

	type state_type is (idle, wait_for_buffer, wait_1, get_buff_2, wait_3, get_buff, wait_encode, output_sk_rand, wait_pk_key_hash, output_pk_key_hash, done_state);
	signal state_kg_wrap : state_type;
	signal m_input       : std_logic_vector(15 downto 0);

	signal small_weights_random_enable : std_logic;
	signal sk_random_enable            : std_logic;

	signal output_f_encoded       : std_logic_vector(7 downto 0);
	signal output_f_encoded_valid : std_logic;
	signal output_g_encoded       : std_logic_vector(7 downto 0);
	signal output_g_encoded_valid : std_logic;

	signal sk_rand_valid : std_logic;

	signal counter : integer range 0 to Small_bytes;

	signal hash_public_key : std_logic;
	signal pk_hash_valid   : std_logic;

	signal sha_hash_out_address : integer range 0 to 3;
	signal sha_hash_out_read_en : std_logic;
	signal sha_hash_out_counter : integer range 0 to 8;
begin

	done_process : process(clock, reset) is
		variable done_reg : std_logic_vector(3 downto 0);
	begin
		if reset = '1' then
			done_reg := (others => '0');
			done     <= '0';
		elsif rising_edge(clock) then
			if done_f = '1' then
				done_reg(3) := '1';
			end if;
			if done_g = '1' then
				done_reg(2) := '1';
			end if;
			if done_pk = '1' then
				done_reg(1) := '1';
			end if;
			if done_key_gen = '1' then
				done_reg(0) := '1';
			end if;
			if done_reg = "1111" and state_kg_wrap = idle then
				done     <= '1';
				done_reg := (others => '0');
			else
				done <= '0';
			end if;

		end if;
	end process done_process;

	buffer_ram_process : process(clock, reset) is
	begin
		if reset = '1' then
			buffer_address_a      <= std_logic_vector(to_unsigned(p - 1, p_num_bits));
			address_b_var         <= 0;
			output_h_valid_buffer <= '0';
			encoder_input_valid   <= '0';
			counter               <= 0;
			sk_rand_valid         <= '0';
			sk_random_enable      <= '0';
			hash_public_key       <= '0';
			pk_hash_valid         <= '0';
			sha_hash_out_read_en  <= '0';
		elsif rising_edge(clock) then
			if output_h_valid = '1' then
				buffer_address_a <= std_logic_vector(unsigned(buffer_address_a) - to_unsigned(1, p_num_bits));
			end if;

			if done_key_gen = '1' then
				buffer_address_a <= std_logic_vector(to_unsigned(p - 1, p_num_bits));
			end if;

			sk_rand_valid <= '0';
			case state_kg_wrap is
				when idle =>
					if output_h_valid = '1' then
						state_kg_wrap <= wait_for_buffer;
					end if;
					address_b_var        <= 0;
					encoder_input_valid  <= '0';
					sk_random_enable     <= '0';
					hash_public_key      <= '0';
					sha_hash_out_read_en <= '0';
				when wait_for_buffer =>
					if output_h_valid = '0' then
						state_kg_wrap <= wait_1;
					end if;
				when wait_1 =>
					state_kg_wrap   <= get_buff;
					hash_public_key <= '1';
				when get_buff =>
					encoder_input_valid <= '1';
					state_kg_wrap       <= get_buff_2;
					hash_public_key     <= '0';
				when get_buff_2 =>
					if output_h_ack = '1' then
						state_kg_wrap <= get_buff_2;
						address_b_var <= address_b_var + 1;
					end if;

					if address_b_var = p then
						state_kg_wrap       <= wait_encode;
						encoder_input_valid <= '0';
					end if;

				when wait_encode =>
					if done_pk = '1' then
						counter          <= 0;
						state_kg_wrap    <= output_sk_rand;
						sk_random_enable <= '0';
						sk_rand_valid    <= '1';
					end if;

				when output_sk_rand =>
					if counter mod 4 = 2 then
						sk_random_enable <= '1';
					else
						sk_random_enable <= '0';
					end if;

					sk_rand_valid <= '1';
					counter       <= counter + 1;

					if counter = Small_bytes - 1 then
						state_kg_wrap    <= wait_pk_key_hash;
						sk_rand_valid    <= '0';
						sk_random_enable <= '1';
					end if;
				when wait_pk_key_hash =>
					sk_random_enable     <= '0';
					counter              <= 0;
					sha_hash_out_read_en <= '1';
					sha_hash_out_counter <= 0;
					if from_sha.hash_finished = '1' then
						state_kg_wrap <= output_pk_key_hash;
						pk_hash_valid <= '1';
					end if;
				when output_pk_key_hash =>
					sha_hash_out_read_en <= '1';
					if counter /= 31 then
						counter <= counter + 1;
					else
						state_kg_wrap <= done_state;
						pk_hash_valid <= '0';
					end if;

					if sha_hash_out_counter = 7 then
						sha_hash_out_counter <= 0;
					else
						sha_hash_out_counter <= sha_hash_out_counter + 1;
					end if;
					if sha_hash_out_counter = 6 then
						sha_hash_out_address <= sha_hash_out_address + 1;
					end if;
				when done_state =>
					state_kg_wrap        <= idle;
					pk_hash_valid        <= '0';
					sha_hash_out_read_en <= '0';
				when others =>
					state_kg_wrap <= idle;
			end case;
		end if;
	end process buffer_ram_process;

	random_enable <= sk_random_enable when state_kg_wrap = output_sk_rand or state_kg_wrap = wait_pk_key_hash else small_weights_random_enable;

	buffer_address_b <= std_logic_vector(to_unsigned(address_b_var, p_num_bits)) when output_h_ack = '0' --
	                    else std_logic_vector(to_unsigned(address_b_var + 1, p_num_bits));

	private_key_out       <= random_output(8 * (4 - (counter mod 4)) - 1 downto 8 * (3 - (counter mod 4))) when state_kg_wrap = output_sk_rand
	                         else from_sha.hash_out(63 - sha_hash_out_counter * 8 downto 64 - (sha_hash_out_counter + 1) * 8) when state_kg_wrap = output_pk_key_hash
	                         else output_f_encoded when output_f_encoded_valid = '1'
	                         else output_g_encoded;
	private_key_out_valid <= output_f_encoded_valid or output_g_encoded_valid or sk_rand_valid or pk_hash_valid;

	key_generation_inst : entity work.key_generation
		port map(
			clock                       => clock,
			reset                       => reset,
			start                       => start,
			ready                       => ready,
			done                        => done_key_gen,
			output_h                    => output_h,
			output_h_valid              => output_h_valid,
			output_h_ack                => output_h_ack,
			output_f                    => output_f,
			output_f_valid              => output_f_valid,
			output_g_recip              => output_g_recip,
			output_g_valid              => output_g_valid,
			random_small_enable         => random_small_enable,
			random_small_poly           => random_small_poly,
			small_weights_random_enable => small_weights_random_enable,
			small_weights_random_output => random_output,
			to_rq_mult                  => to_rq_mult,
			from_rq_mult                => from_rq_mult,
			to_small_weights            => to_small_weights,
			from_small_weights          => from_small_weights
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

	buffer_data_in_a_shift <= std_logic_vector(resize(signed(output_h), q_num_bits + 1) + q12);
	buffer_data_in_a       <= buffer_data_in_a_shift(q_num_bits - 1 downto 0);
	buffer_write_a         <= output_h_valid;

	m_input <= std_logic_vector(to_unsigned(q, 16));

	to_encode_Rq.input       <= buffer_data_out_b;
	to_encode_Rq.input_valid <= encoder_input_valid;
	to_encode_Rq.m_input     <= m_input;

	output_h_ack     <= from_encode_Rq.input_ack;
	encoded_pk       <= from_encode_Rq.output;
	encoded_pk_valid <= from_encode_Rq.output_valid;
	done_pk          <= from_encode_Rq.done;

	encode_R3_inst_f : entity work.encode_R3(RTL2)
		port map(
			clock        => clock,
			reset        => reset,
			input        => output_f,
			input_valid  => output_f_valid,
			output       => output_f_encoded,
			output_valid => output_f_encoded_valid,
			done         => done_f
		);

	encode_R3_inst_g : entity work.encode_R3(RTL2)
		port map(
			clock        => clock,
			reset        => reset,
			input        => output_g_recip,
			input_valid  => output_g_valid,
			output       => output_g_encoded,
			output_valid => output_g_encoded_valid,
			done         => done_g
		);

	to_sha.new_public_key    <= hash_public_key;
	to_sha.public_key_in     <= from_encode_Rq.output;
	to_sha.public_key_ready  <= from_encode_Rq.output_valid;
	to_sha.new_pk_cache      <= '0';
	to_sha.pk_cache_in       <= (others => '0');
	to_sha.pk_cache_in_valid <= '0';

	to_sha.start_confirm         <= '0';
	to_sha.r_encoded_in          <= (others => '0');
	to_sha.r_encoded_in_valid    <= '0';
	to_sha.start_session         <= '0';
	to_sha.re_encap_session      <= '0';
	to_sha.diff_mask             <= (others => '0');
	to_sha.c_encoded_in          <= (others => '0');
	to_sha.c_encoded_in_valid    <= '0';
	to_sha.decode_Rq_input_ack   <= from_encode_Rq.output_valid;
	to_sha.decode_Rq_input_valid <= from_encode_Rq.output_valid;

	to_sha.hash_out_address      <= std_logic_vector(to_unsigned(sha_hash_out_address, 2));
	to_sha.hash_out_read_en      <= sha_hash_out_read_en;
	to_sha.hash_out_read_pub_key <= '1';
	to_sha.hash_out_read_confirm <= '0';

end architecture RTL;

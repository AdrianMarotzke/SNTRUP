library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.constants.all;

-- This package contains all common data types and functions that are need across modules
package data_type is
	type small_polynomial is array (integer range <>) of signed(1 downto 0);

	type polynomial is array (integer range <>) of integer;

	type exponents_type is array (encoding_batch - 1 downto 0) of unsigned(63 downto 0);

	type sha_record_in_type is record
		new_public_key        : std_logic;
		public_key_in         : std_logic_vector(7 downto 0);
		public_key_ready      : std_logic;
		new_pk_cache          : std_logic;
		pk_cache_in           : std_logic_vector(7 downto 0);
		pk_cache_in_valid     : std_logic;
		start_confirm         : std_logic;
		r_encoded_in          : std_logic_vector(7 downto 0);
		r_encoded_in_valid    : std_logic;
		start_session         : std_logic;
		re_encap_session      : std_logic;
		diff_mask             : std_logic_vector(7 downto 0);
		c_encoded_in          : std_logic_vector(7 downto 0);
		c_encoded_in_valid    : std_logic;
		decode_Rq_input_ack   : std_logic;
		decode_Rq_input_valid : std_logic;
		hash_out_address      : std_logic_vector(1 downto 0);
		hash_out_read_en      : std_logic;
		hash_out_read_pub_key : std_logic;
		hash_out_read_confirm : std_logic;
	end record sha_record_in_type;
	type sha_record_out_type is record
		hash_finished      : std_logic;
		hash_ack_new_input : std_logic;
		hash_out           : std_logic_vector(64 - 1 downto 0);
	end record sha_record_out_type;

	type decode_Rq_in_type is record
		start          : std_logic;
		input          : std_logic_vector(7 downto 0);
		input_valid    : std_logic;
		rounded_decode : std_logic;
	end record decode_Rq_in_type;

	type decode_Rq_out_type is record
		input_ack    : std_logic;
		output       : std_logic_vector(q_num_bits - 1 downto 0);
		output_valid : std_logic;
		done         : std_logic;
	end record decode_Rq_out_type;

	type encode_Rq_in_type is record
		input       : std_logic_vector(q_num_bits - 1 downto 0);
		input_valid : std_logic;
		m_input     : std_logic_vector(15 downto 0);
	end record encode_Rq_in_type;

	type encode_Rq_out_type is record
		input_ack    : std_logic;
		output       : std_logic_vector(7 downto 0);
		output_valid : std_logic;
		done         : std_logic;
	end record encode_Rq_out_type;

	constant encode_Rq_out_constant_zero : encode_Rq_out_type := ('0', (others => '0'), '0', '0');

	type encap_core_in_type is record
		start_encap         : std_logic;
		new_public_key      : std_logic;
		public_key_in       : std_logic_vector(q_num_bits - 1 downto 0);
		public_key_valid    : std_logic;

		small_weights_out   : std_logic_vector(1 downto 0);
		small_weights_valid : std_logic;
		small_weights_done  : std_logic;
	end record encap_core_in_type;

	type encap_core_out_type is record
		ready               : std_logic;
		done                : std_logic;

		public_key_ready    : std_logic;
		c_encrypt           : std_logic_vector(q_num_bits - 1 downto 0);
		c_encrypt_valid     : std_logic;
		r_secret            : std_logic_vector(1 downto 0);
		r_secret_valid      : std_logic;
		small_weights_start : std_logic;
	end record encap_core_out_type;

	type rq_multiplication_in_type is record
		start             : std_logic;
		output_ack        : std_logic;  -- Unused
		bram_f_data_out_a : std_logic_vector(q_num_bits - 1 downto 0);
		bram_f_data_out_b : std_logic_vector(q_num_bits - 1 downto 0);
		bram_g_data_out_a : std_logic_vector(2 - 1 downto 0);
		bram_g_data_out_b : std_logic_vector(2 - 1 downto 0);

	end record rq_multiplication_in_type;

	type rq_multiplication_out_type is record
		ready            : std_logic;
		output_valid     : std_logic;
		output           : std_logic_vector(q_num_bits - 1 downto 0);
		done             : std_logic;
		bram_f_address_a : std_logic_vector(p_num_bits - 1 downto 0);
		bram_f_address_b : std_logic_vector(p_num_bits - 1 downto 0);
		bram_g_address_a : std_logic_vector(p_num_bits - 1 downto 0);
		bram_g_address_b : std_logic_vector(p_num_bits - 1 downto 0);
	end record rq_multiplication_out_type;

	type small_random_weights_in_type is record
		start         : std_logic;
		random_output : std_logic_vector(31 downto 0);
	end record small_random_weights_in_type;

	type small_random_weights_out_type is record
		small_weights_valid : std_logic;
		small_weights_out   : signed(1 downto 0);
		done                : std_logic;
		random_enable       : std_logic;
	end record small_random_weights_out_type;

	type mod3_freeze_round_in_type is record
		input  : signed(q_num_bits - 1 downto 0);
		enable : std_logic;
	end record mod3_freeze_round_in_type;

	type mod3_freeze_round_out_type is record
		output         : signed(1 downto 0);
		output_rounded : signed(q_num_bits - 1 downto 0);
		output_valid   : std_logic;
	end record mod3_freeze_round_out_type;

	type mult_ram_address is record
		bram_f_address_a : std_logic_vector(p_num_bits - 1 downto 0);
		bram_f_address_b : std_logic_vector(p_num_bits - 1 downto 0);
		bram_g_address_a : std_logic_vector(p_num_bits - 1 downto 0);
		bram_g_address_b : std_logic_vector(p_num_bits - 1 downto 0);
	end record mult_ram_address;

	type mult_ram_data is record
		f_data_out_a : std_logic_vector(q_num_bits - 1 downto 0);
		f_data_out_b : std_logic_vector(q_num_bits - 1 downto 0);
		g_data_out_a : std_logic_vector(2 - 1 downto 0);
		g_data_out_b : std_logic_vector(2 - 1 downto 0);
	end record mult_ram_data;

	type mult_ram_data_3bit is record
		f_data_out_a : std_logic_vector(q_num_bits - 1 downto 0);
		f_data_out_b : std_logic_vector(q_num_bits - 1 downto 0);
		g_data_out_a : std_logic_vector(3 - 1 downto 0);
		g_data_out_b : std_logic_vector(3 - 1 downto 0);
	end record mult_ram_data_3bit;

	type mult_ram_data_4bit is record
		f_data_out_a : std_logic_vector(q_num_bits - 1 downto 0);
		f_data_out_b : std_logic_vector(q_num_bits - 1 downto 0);
		g_data_out_a : std_logic_vector(4 - 1 downto 0);
		g_data_out_b : std_logic_vector(4 - 1 downto 0);
	end record mult_ram_data_4bit;

	type mult_output is record
		output_low  : std_logic_vector(q_num_bits - 1 downto 0);
		output_mid  : std_logic_vector(q_num_bits - 1 downto 0);
		output_high : std_logic_vector(q_num_bits - 1 downto 0);
	end record mult_output;

	constant mod3_freeze_round_zero : mod3_freeze_round_out_type := ((others => '0'), (others => '0'), '0');

	constant rq_mult_out_type_zero : rq_multiplication_out_type := ('0', '0', (others => '0'), '0', (others => '0'), (others => '0'), (others => '0'), (others => '0'));

	function non_zero_mask(x : signed) return signed;

	function negative_mask(x : signed) return signed;

	function calc_exponents return exponents_type; -- not used

	type divmod_cmd is (cmd_store_remainder, cmd_store_both, cmd_output_both, cmd_output_r0_only);

	function pre_calc_M(M_input : polynomial; length : integer) return polynomial; -- not used

end package data_type;

package body data_type is
	function non_zero_mask(x : signed)
	return signed is
	begin
		if x = to_signed(0, 16) then
			return to_signed(0, 16);
		else
			return to_signed(-1, 16);
		end if;
	end function non_zero_mask;

	function negative_mask(x : signed)
	return signed is
	begin
		if x >= to_signed(0, 16) then
			return to_signed(0, 16);
		else
			return to_signed(-1, 16);
		end if;
	end function negative_mask;

	function calc_exponents
	return exponents_type is
		variable temp : exponents_type;
	begin
		temp(0) := to_unsigned(1, 64);
		for i in 1 to encoding_batch - 1 loop
			temp(i) := resize(encoding_radix * temp(i - 1), 64);
		end loop;
		return temp;
	end function calc_exponents;

	-- Function to precalute all values for M, for the precaluted divisors. Not used yet
	function pre_calc_M(M_input : polynomial; length : integer) return polynomial is

		variable m : integer := 0;

		variable i : integer := 0;

		variable M2 : polynomial(length / 2 - 1 downto 0);

		variable M_ret : polynomial(length - 1 downto 0);

	begin
		if length = 1 then
			return M_input;
		end if;

		while i < length - 1 loop
			m := M_input(i) * M_input(i + 1);
			if m > 256 * 16383 then
				M2(i / 2) := ((m + 255) / 2**8 + 255) / 2**8;
			elsif m > 16384 then
				M2(i / 2) := (m + 255) / 2**8;
			else
				M2(i / 2) := m;
			end if;
			i := i + 2;
		end loop;

		if i < length then
			M2(i / 2) := M_input(i);
		end if;

		M_ret(length / 2 - 1 downto 0)      := pre_calc_M(M2, length / 2); -- TODO Check if working
		M_ret(length - 1 downto length / 2) := M2;

		return M_ret;
	end function pre_calc_M;

end package body data_type;

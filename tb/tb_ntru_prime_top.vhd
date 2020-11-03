library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use std.textio.all;
use work.constants.all;

entity tb_ntru_prime_top is
end entity tb_ntru_prime_top;

architecture RTL of tb_ntru_prime_top is
	signal clock : std_logic := '0';
	signal reset : std_logic := '0';
	signal ready : std_logic;
	signal done  : std_logic;

	signal public_key_in       : std_logic_vector(7 downto 0);
	signal public_key_in_valid : std_logic;
	signal public_key_in_ack   : std_logic;
	signal set_new_public_key  : std_logic;
	signal public_key_is_set   : std_logic;
	signal random_enable       : std_logic;
	signal random_output       : std_logic_vector(31 downto 0);
	signal start_encap         : std_logic;
	signal cipher_output       : std_logic_vector(7 downto 0);
	signal output_tb           : std_logic_vector(7 downto 0);
	signal cipher_output_valid : std_logic;
	signal k_hash_out          : std_logic_vector(63 downto 0);
	--signal k_hash_out          : std_logic_vector(127 downto 0);
	signal k_hash_out_tb       : std_logic_vector(255 downto 0);
	signal k_out_valid         : std_logic;

	signal start_key_gen        : std_logic;
	signal start_decap          : std_logic;
	signal set_new_private_key  : std_logic;
	signal private_key_in       : std_logic_vector(7 downto 0);
	signal private_key_in_valid : std_logic;
	signal private_key_in_ack   : std_logic;
	signal cipher_input         : std_logic_vector(7 downto 0);
	signal cipher_input_valid   : std_logic;
	signal cipher_input_ack     : std_logic;
	signal private_key_is_set   : std_logic;

	signal private_key_out       : std_logic_vector(7 downto 0);
	signal private_key_out_valid : std_logic;
	signal public_key_out        : std_logic_vector(7 downto 0);
	signal public_key_out_valid  : std_logic;

	signal private_key_out_tb : std_logic_vector(7 downto 0);

	function to_std_logic_vector(a : string) return std_logic_vector is
		variable ret : std_logic_vector(a'length * 4 - 1 downto 0);
	begin
		for i in a'range loop
			case a(i) is
				when '0'    => ret((a'length - i) * 4 + 3 downto (a'length - i) * 4) := "0000";
				when '1'    => ret((a'length - i) * 4 + 3 downto (a'length - i) * 4) := "0001";
				when '2'    => ret((a'length - i) * 4 + 3 downto (a'length - i) * 4) := "0010";
				when '3'    => ret((a'length - i) * 4 + 3 downto (a'length - i) * 4) := "0011";
				when '4'    => ret((a'length - i) * 4 + 3 downto (a'length - i) * 4) := "0100";
				when '5'    => ret((a'length - i) * 4 + 3 downto (a'length - i) * 4) := "0101";
				when '6'    => ret((a'length - i) * 4 + 3 downto (a'length - i) * 4) := "0110";
				when '7'    => ret((a'length - i) * 4 + 3 downto (a'length - i) * 4) := "0111";
				when '8'    => ret((a'length - i) * 4 + 3 downto (a'length - i) * 4) := "1000";
				when '9'    => ret((a'length - i) * 4 + 3 downto (a'length - i) * 4) := "1001";
				when 'A'    => ret((a'length - i) * 4 + 3 downto (a'length - i) * 4) := "1010";
				when 'B'    => ret((a'length - i) * 4 + 3 downto (a'length - i) * 4) := "1011";
				when 'C'    => ret((a'length - i) * 4 + 3 downto (a'length - i) * 4) := "1100";
				when 'D'    => ret((a'length - i) * 4 + 3 downto (a'length - i) * 4) := "1101";
				when 'E'    => ret((a'length - i) * 4 + 3 downto (a'length - i) * 4) := "1110";
				when 'F'    => ret((a'length - i) * 4 + 3 downto (a'length - i) * 4) := "1111";
				when others => null;
			end case;

		end loop;
		return ret;
	end function to_std_logic_vector;

	signal kat_num : integer := 0;

	constant param_set : string(1 to 3) := integer'image(p);

	procedure encap_test(signal set_new_public_key : out std_logic; signal start_encap : out std_logic) is
	begin
		wait for 200 ns;
		wait until rising_edge(clock);
		wait for 1 ns;
		set_new_public_key <= '1';
		wait until rising_edge(clock);
		wait for 1 ns;
		set_new_public_key <= '0';
		wait until rising_edge(clock) and public_key_is_set = '1' and ready = '1';

		wait for 1 ns;
		start_encap <= '1';
		wait until rising_edge(clock);
		wait for 1 ns;
		start_encap <= '0';
		wait until rising_edge(clock) and done = '1';
		wait for 1000 ns;
		wait until rising_edge(clock) and public_key_is_set = '1' and ready = '1';

		wait for 1 ns;
		start_encap <= '1';
		wait until rising_edge(clock);
		wait for 1 ns;
		start_encap <= '0';
		wait until rising_edge(clock) and done = '1';
		wait until rising_edge(clock) and public_key_is_set = '1' and ready = '1';

		wait for 1 ns;
		set_new_public_key <= '1';
		wait until rising_edge(clock);
		wait for 1 ns;
		set_new_public_key <= '0';
		wait until rising_edge(clock) and public_key_is_set = '1' and ready = '1';

		wait for 1 ns;
		start_encap <= '1';
		wait until rising_edge(clock);
		wait for 1 ns;
		start_encap <= '0';
		wait until rising_edge(clock) and done = '1';
		wait for 1000 ns;
		wait until rising_edge(clock) and public_key_is_set = '1' and ready = '1';
	end procedure encap_test;

	procedure decap_test(signal set_new_private_key : out std_logic; signal start_decap : out std_logic) is
	begin
		wait for 200 ns;
		wait until rising_edge(clock);
		wait for 1 ns;
		set_new_private_key <= '1';
		wait until rising_edge(clock);
		wait for 1 ns;
		set_new_private_key <= '0';

		wait until rising_edge(clock) and ready = '1' and private_key_is_set = '1';
		wait for 1 ns;
		start_decap <= '1';
		wait until rising_edge(clock);
		wait for 1 ns;
		start_decap <= '0';
		wait until rising_edge(clock) and done = '1';

		wait for 1 ns;
		start_decap <= '1';
		wait until rising_edge(clock);
		wait for 1 ns;
		start_decap <= '0';
		wait until rising_edge(clock) and done = '1';
		wait for 1 ns;

		start_decap         <= '0';
		set_new_private_key <= '0';
		wait for 200 ns;
		wait until rising_edge(clock);
		wait for 1 ns;
		set_new_private_key <= '1';
		wait until rising_edge(clock);
		wait for 1 ns;
		set_new_private_key <= '0';
		wait until rising_edge(clock) and ready = '1' and private_key_is_set = '1';

		wait for 1 ns;
		start_decap <= '1';
		wait until rising_edge(clock);
		wait for 1 ns;
		start_decap <= '0';
		wait until rising_edge(clock) and done = '1';
		wait for 1 ns;
		start_decap <= '1';
		wait until rising_edge(clock);
		wait for 1 ns;
		start_decap <= '0';
		wait until rising_edge(clock) and done = '1';
		wait for 1 ns;
	end procedure decap_test;

begin
	ntru_prime_top_inst : entity work.ntru_prime_top
		port map(
			clock                 => clock,
			reset                 => reset,
			ready                 => ready,
			done                  => done,
			start_key_gen         => start_key_gen,
			start_encap           => start_encap,
			start_decap           => start_decap,
			set_new_public_key    => set_new_public_key,
			public_key_in         => public_key_in,
			public_key_in_valid   => public_key_in_valid,
			public_key_in_ack     => public_key_in_ack,
			public_key_is_set     => public_key_is_set,
			set_new_private_key   => set_new_private_key,
			private_key_in        => private_key_in,
			private_key_in_valid  => private_key_in_valid,
			private_key_in_ack    => private_key_in_ack,
			private_key_is_set    => private_key_is_set,
			cipher_output         => cipher_output,
			cipher_output_valid   => cipher_output_valid,
			cipher_input          => cipher_input,
			cipher_input_valid    => cipher_input_valid,
			cipher_input_ack      => cipher_input_ack,
			k_hash_out            => k_hash_out,
			k_out_valid           => k_out_valid,
			private_key_out       => private_key_out,
			private_key_out_valid => private_key_out_valid,
			public_key_out        => public_key_out,
			public_key_out_valid  => public_key_out_valid,
			--random_small_enable   => random_small_enable,
			--random_small_output   => random_small_output,
			random_enable         => random_enable,
			random_output         => random_output
		);

	clock_gen : process is
	begin
		clock <= not clock;
		wait for 2 ns;
	end process clock_gen;

	reset_gen : process is
	begin
		reset <= '1';
		wait for 110 ns;
		wait until rising_edge(clock);
		wait for 1 ns;
		reset <= '0';
		wait;
	end process reset_gen;

	enable_gen : process is
	begin
		start_encap         <= '0';
		set_new_public_key  <= '0';
		start_decap         <= '0';
		set_new_private_key <= '0';
		start_key_gen       <= '0';

		wait for 200 ns;
		wait until rising_edge(clock);
		wait for 1 ns;
		start_key_gen <= '1';
		wait until rising_edge(clock);
		wait for 1 ns;
		start_key_gen <= '0';
		wait until rising_edge(clock) and done = '1';

		encap_test(set_new_public_key, start_encap);

		decap_test(set_new_private_key, start_decap);

		if kat_num < 50 then
			kat_num <= kat_num + 1;
		else
			wait;
		end if;

		--wait;
	end process enable_gen;

	stimulus_pk : process is
		file read_file    : text;
		variable line_v   : line;
		variable temp8bit : string(1 to 2);

	begin
		public_key_in_valid <= '0';
		wait until rising_edge(clock) and set_new_public_key = '1';
		wait for 1 ns;

		file_open(read_file, "./tb_stimulus/KAT_" & param_set & "/pk_tb", read_mode);

		for i in 0 to kat_num loop
			readline(read_file, line_v);
		end loop;

		for i in 0 to PublicKeys_bytes - 1 loop
			read(line_v, temp8bit);
			public_key_in       <= to_std_logic_vector(temp8bit);
			public_key_in_valid <= '1';
			wait until rising_edge(clock) and public_key_in_ack = '1';
			wait for 1 ns;
		end loop;

		--end loop;
		public_key_in_valid <= '0';
		file_close(read_file);
		wait until rising_edge(clock);
	end process stimulus_pk;

	stimulus_rand_32bit : process is
		file read_file    : text;
		variable line_v   : line;
		variable temp8bit : string(1 to 8);
	begin
		wait until start_encap = '1' or start_key_gen = '1';
		if start_key_gen = '1' then
			file_open(read_file, "./tb_stimulus/KAT_" & param_set & "/short_random_tb", read_mode);

			for i in 0 to kat_num loop
				readline(read_file, line_v);
			end loop;

			if line_v'length > (p + p + Small_bytes / 4 + 1 + 50) * 8 then
				for i in 0 to p + p + p - 1 + Small_bytes / 4 + 1 loop
					read(line_v, temp8bit);
					random_output <= to_std_logic_vector(temp8bit);
					wait until rising_edge(clock) and random_enable = '1';
					wait for 1 ns;
				end loop;
				
			else
				
				for i in 0 to p + p - 1 + Small_bytes / 4 + 1 loop
					read(line_v, temp8bit);
					random_output <= to_std_logic_vector(temp8bit);
					wait until rising_edge(clock) and random_enable = '1';
					wait for 1 ns;
				end loop;
			end if;

		elsif start_encap = '1' then
			file_open(read_file, "./tb_stimulus/KAT_" & param_set & "/inputs_random_tb", read_mode);

			for i in 0 to kat_num loop
				readline(read_file, line_v);
			end loop;

			for i in 0 to p - 1 loop
				read(line_v, temp8bit);
				random_output <= to_std_logic_vector(temp8bit);
				wait until rising_edge(clock) and random_enable = '1';
				wait for 1 ns;
			end loop;

		end if;

		file_close(read_file);
	end process stimulus_rand_32bit;

	check_encap_output : process is
		file read_file    : text;
		variable line_v   : line;
		variable temp8bit : string(1 to 2);
	begin
		file_open(read_file, "./tb_stimulus/KAT_" & param_set & "/ct_tb", read_mode);

		wait until cipher_output_valid = '1';

		for i in 0 to kat_num loop
			readline(read_file, line_v);
		end loop;

		for i in 0 to ct_with_confirm_bytes - 1 loop
			read(line_v, temp8bit);
			output_tb <= to_std_logic_vector(temp8bit);
			wait until rising_edge(clock) and cipher_output_valid = '1';
			assert output_tb = cipher_output or (cipher_output_valid /= '1') report "Mismatch in encap output" severity failure;
		end loop;

		file_close(read_file);
		wait until rising_edge(clock);
	end process check_encap_output;

	check_sk_key_gen_output : process is
		file read_file    : text;
		variable line_v   : line;
		variable temp8bit : string(1 to 2);
	begin
		file_open(read_file, "./tb_stimulus/KAT_" & param_set & "/sk_tb", read_mode);

		wait until private_key_out_valid = '1';

		for i in 0 to kat_num loop
			readline(read_file, line_v);
		end loop;

		for i in 0 to SecretKey_bytes - 1 loop
			read(line_v, temp8bit);
			private_key_out_tb <= to_std_logic_vector(temp8bit);
			wait until rising_edge(clock) and (private_key_out_valid = '1' or public_key_out_valid = '1');
			assert private_key_out_tb = private_key_out or (private_key_out_valid /= '1') report "Mismatch in sk key_gen output" severity failure;
			assert private_key_out_tb = public_key_out or (public_key_out_valid /= '1') report "Mismatch in pk key_gen output" severity failure;

		end loop;

		wait until rising_edge(clock);

		file_close(read_file);
	end process check_sk_key_gen_output;

	stimulus_sk : process is
		file read_file    : text;
		variable line_v   : line;
		variable temp8bit : string(1 to 2);
	begin
		file_open(read_file, "./tb_stimulus/KAT_" & param_set & "/sk_tb", read_mode);

		private_key_in_valid <= '0';

		wait until set_new_private_key = '1';

		for i in 0 to kat_num loop
			readline(read_file, line_v);
		end loop;

		private_key_in_valid <= '0';
		wait until rising_edge(clock) and set_new_private_key = '1';
		wait for 1 ns;

		for i in 0 to SecretKey_bytes - 1 loop
			read(line_v, temp8bit);
			private_key_in       <= to_std_logic_vector(temp8bit);
			private_key_in_valid <= '1';
			wait until rising_edge(clock) and private_key_in_ack = '1';
			wait for 1 ns;
		end loop;
		private_key_in_valid <= '0';
		file_close(read_file);

		wait until rising_edge(clock);
	end process stimulus_sk;

	stimulus_c : process is
		file read_file    : text;
		variable line_v   : line;
		variable temp8bit : string(1 to 2);
	begin
		file_open(read_file, "./tb_stimulus/KAT_" & param_set & "/ct_tb", read_mode);

		cipher_input_valid <= '0';
		wait until rising_edge(clock) and start_decap = '1';
		wait for 1 ns;

		for i in 0 to kat_num loop
			readline(read_file, line_v);
		end loop;

		for i in 0 to ct_with_confirm_bytes - 1 loop
			read(line_v, temp8bit);
			cipher_input       <= to_std_logic_vector(temp8bit);
			cipher_input_valid <= '1';
			wait until rising_edge(clock) and cipher_input_ack = '1';
			wait for 1 ns;
		end loop;
		cipher_input_valid <= '0';
		file_close(read_file);
	end process stimulus_c;

	check_hash_output : process is
		file read_file    : text;
		variable line_v   : line;
		variable temp8bit : string(1 to 64);
	begin
		file_open(read_file, "./tb_stimulus/KAT_" & param_set & "/hash_tb", read_mode);

		wait until k_out_valid = '1';

		for i in 0 to kat_num loop
			readline(read_file, line_v);
		end loop;

		read(line_v, temp8bit);
		k_hash_out_tb <= to_std_logic_vector(temp8bit);

		wait until rising_edge(clock) and k_out_valid = '1';

		assert k_hash_out_tb(255 downto 192) = k_hash_out report "Mismatch in k hash output 0" severity failure;

		wait until rising_edge(clock) and k_out_valid = '1';

		assert k_hash_out_tb(191 downto 128) = k_hash_out report "Mismatch in k hash output 1" severity failure;

		wait until rising_edge(clock) and k_out_valid = '1';

		assert k_hash_out_tb(127 downto 64) = k_hash_out report "Mismatch in k hash output 2" severity failure;

		wait until rising_edge(clock) and k_out_valid = '1';

		assert k_hash_out_tb(63 downto 0) = k_hash_out report "Mismatch in k hash output 3" severity failure;

		file_close(read_file);

		wait until rising_edge(clock);
	end process check_hash_output;

end architecture RTL;

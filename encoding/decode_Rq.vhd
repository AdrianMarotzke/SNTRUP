library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.constants.all;
use work.data_type.all;

-- Decode from byte stream to Rq polynomaial. Does not shift elements by q!
entity decode_Rq is
	port(
		clock          : in  std_logic;
		reset          : in  std_logic;
		start          : in  std_logic;
		input          : in  std_logic_vector(7 downto 0);
		input_valid    : in  std_logic;
		input_ack      : out std_logic;
		rounded_decode : in  std_logic;
		output         : out std_logic_vector(q_num_bits - 1 downto 0);
		output_valid   : out std_logic;
		done           : out std_logic
	);
end entity decode_Rq;

architecture RTL of decode_Rq is

	type state_type is (idle, loop_input, loop_input_one, loop_input_two, loop_input_two_r, next_recursion, loop_finalize, recursion_end_wait,
	                    recursion_end, recursion_end_2, recursion_end_3, begin_recusion, loop_one_d, loop_if_prep, loop_if_case,
	                    loop_if_one_S0,
	                    loop_if_one_S1, loop_if_two, loop_if_three, next_loop, loop_two_prep, loop_two_case, loop_two_wait,
	                    loop_two_fma, loop_two_divmod, loop_two_store, loop_two_d_end, loop_two_d_end_write, loop_two_flush,
	                    output_loop, output_loop_wait, output_loop_fma, output_loop_divmod, output_loop_end, output_loop_end_2,
	                    output_end_write, output_flush_pipe, decode_done
	                   );
	signal state_decode : state_type;

	signal i          : integer range 0 to p;
	signal reg_length : integer range 0 to p;

	constant max_depth : integer := p_num_bits;

	signal depth_counter : integer range 0 to max_depth;

	signal reg_S0 : std_logic_vector(7 downto 0);
	signal reg_S1 : std_logic_vector(7 downto 0);

	signal reg_m : unsigned(31 downto 0);
	signal reg_m2 : unsigned(31 downto 0);

	signal reg_r  : unsigned(31 downto 0);
	signal reg_r0 : unsigned(15 downto 0);
	signal reg_r1 : unsigned(15 downto 0);

	signal reg_Mi0 : unsigned(15 downto 0);
	--signal reg_Mi1 : unsigned(15 downto 0);

	signal address_offset      : integer range 0 to 2**p_num_bits;
	signal address_offset_next : integer range 0 to 2**p_num_bits;

	signal pop_stack  : std_logic;
	signal push_stack : std_logic;

	signal stack_input  : integer range 0 to 2**p_num_bits;
	signal stack_output : integer range 0 to 2**p_num_bits;

	signal output_reg_r0      : std_logic;
	signal output_reg_r1      : std_logic;
	signal output_reg_r0_only : std_logic;

	signal dividend : std_logic_vector(31 downto 0);

	signal divisor_index     : std_logic_vector(6 downto 0);
	signal divisor_index_mod : std_logic_vector(6 downto 0);

	signal remainder_mod : std_logic_vector(15 downto 0);

	signal decode_command_pipe_in  : std_logic;
	signal decode_command_pipe_out : std_logic;

	signal bram_R2_address_pipe_in  : std_logic_vector(p_num_bits - 1 downto 0);
	signal bram_R2_address_pipe_out : std_logic_vector(p_num_bits - 1 downto 0);

	signal store_cmd_pipe_in  : divmod_cmd;
	signal store_cmd_pipe_out : divmod_cmd;

	signal remainder_pipe_delay_out : std_logic_vector(15 downto 0);

	signal pipe_flush_counter : integer range 0 to 66;

	signal decode_command    : std_logic;
	signal reg_store_both    : std_logic;
	signal reg_store_address : std_logic_vector(p_num_bits - 1 downto 0);
	signal reg_remainder_mod : std_logic_vector(15 downto 0);

	signal bram_R2_address_a  : std_logic_vector(p_num_bits - 1 downto 0);
	signal bram_R2_write_a    : std_logic;
	signal bram_R2_data_in_a  : std_logic_vector(15 downto 0);
	signal bram_R2_data_out_a : std_logic_vector(15 downto 0);
	signal bram_R2_address_b  : std_logic_vector(p_num_bits - 1 downto 0);
	signal bram_R2_write_b    : std_logic;
	signal bram_R2_data_in_b  : std_logic_vector(15 downto 0);
	--signal bram_R2_data_out_b : std_logic_vector(15 downto 0);

	signal bram_br_address_a  : std_logic_vector(p_num_bits - 1 downto 0);
	signal bram_br_write_a    : std_logic;
	signal bram_br_data_in_a  : std_logic_vector(15 downto 0);
	signal bram_br_data_out_a : std_logic_vector(15 downto 0);
	signal bram_br_address_b  : std_logic_vector(p_num_bits - 1 downto 0);
	signal bram_br_write_b    : std_logic;
	signal bram_br_data_in_b  : std_logic_vector(15 downto 0);
	--signal bram_br_data_out_b : std_logic_vector(15 downto 0);

	signal rounded_index_offset : integer range 0 to 21;

begin

	fsm_process : process(clock, reset) is
		variable i_2_before_end : integer := 0;

	begin
		if reset = '1' then
			state_decode <= idle;

			decode_command_pipe_in <= '0';

			bram_R2_write_a <= '0';
			--bram_R2_write_b <= '0';

			bram_br_write_a <= '0';
			bram_br_write_b <= '0';

			push_stack <= '0';
			pop_stack  <= '0';

			done <= '0';
		elsif rising_edge(clock) then
			case state_decode is
				when idle =>
					if start = '1' then
						state_decode <= loop_input;
					end if;
					i             <= 0;
					depth_counter <= 0;

					address_offset      <= 0;
					address_offset_next <= 0;

					reg_length <= p;

					bram_R2_write_a <= '0';
					--bram_R2_write_b <= '0';

					bram_br_write_a <= '0';
					bram_br_write_b <= '0';

					push_stack <= '0';
					pop_stack  <= '0';

					done <= '0';

					decode_command_pipe_in  <= '0';
					bram_R2_address_pipe_in <= (others => '0');
				when loop_input =>
					if i < reg_length - 1 then
						if input_valid = '1' then
							state_decode <= loop_input_one;
							reg_S0       <= input;
						end if;
					else
						state_decode <= next_recursion;
					end if;
					bram_br_write_a <= '0';
				when loop_input_one =>
					if rounded_decode = '1' then
						state_decode <= loop_input_two_r;
					else
						if input_valid = '1' then
							state_decode <= loop_input_two;
						end if;

						reg_S1 <= input;
					end if;

				when loop_input_two =>
					state_decode      <= loop_input;
					bram_br_data_in_a <= std_logic_vector(unsigned(reg_S0) + shift_left(resize(unsigned(reg_S1), 16), 8));
					bram_br_address_a <= std_logic_vector(to_unsigned(i / 2, p_num_bits));
					bram_br_write_a   <= '1';

					i <= i + 2;
				when loop_input_two_r =>
					state_decode      <= loop_input;
					bram_br_data_in_a <= std_logic_vector(resize(unsigned(reg_S0), 16));
					bram_br_address_a <= std_logic_vector(to_unsigned(i / 2, p_num_bits));
					bram_br_write_a   <= '1';

					i <= i + 2;
				when next_recursion =>
					state_decode        <= begin_recusion;
					depth_counter       <= depth_counter + 1;
					address_offset      <= address_offset_next;
					address_offset_next <= address_offset_next + (reg_length + 1) / 2;
					reg_length          <= (reg_length + 1) / 2;
					i                   <= 0;

					stack_input <= reg_length;
					push_stack  <= '1';
				when begin_recusion =>
					if reg_length = 1 then
						state_decode <= recursion_end_wait;
					else
						state_decode <= loop_one_d;
					end if;

					push_stack <= '0';
				when recursion_end_wait =>
					state_decode <= recursion_end;
				when recursion_end =>
					if M_array(depth_counter + rounded_index_offset) = 1 then -- TODO This never happens at the moment
						state_decode <= loop_two_flush; --loop_two_case;

						dividend                <= std_logic_vector(to_unsigned(q, 32));
						divisor_index           <= std_logic_vector(to_unsigned(0, 7));
						divisor_index_mod       <= std_logic_vector(to_unsigned(0, 7));
						decode_command_pipe_in  <= '1';
						bram_R2_address_pipe_in <= std_logic_vector(to_unsigned(address_offset, p_num_bits));
						store_cmd_pipe_in       <= cmd_store_remainder;
					else
						if input_valid = '1' then
							reg_S0       <= input;
							state_decode <= recursion_end_2;
						end if;
						reg_Mi0 <= to_unsigned(M_array(depth_counter + rounded_index_offset), 16);
					end if;
					pipe_flush_counter <= 0;
				when recursion_end_2 =>
					if reg_Mi0 <= to_unsigned(256, 16) then
						state_decode            <= loop_two_flush; --loop_two_case;
						dividend                <= std_logic_vector(resize(unsigned(reg_S0), 32));
						divisor_index           <= std_logic_vector(to_unsigned(depth_counter + rounded_index_offset, 7));
						divisor_index_mod       <= std_logic_vector(to_unsigned(depth_counter + rounded_index_offset, 7));
						decode_command_pipe_in  <= '1';
						bram_R2_address_pipe_in <= std_logic_vector(to_unsigned(address_offset, p_num_bits));
						store_cmd_pipe_in       <= cmd_store_remainder;
					else
						if input_valid = '1' then
							reg_S1       <= input;
							state_decode <= recursion_end_3;
						end if;
					end if;
				when recursion_end_3 =>
					state_decode            <= loop_two_flush; --loop_two_prep;
					dividend                <= std_logic_vector(resize(unsigned(reg_S1) & unsigned(reg_S0), 32));
					divisor_index           <= std_logic_vector(to_unsigned(depth_counter + rounded_index_offset, 7));
					divisor_index_mod       <= std_logic_vector(to_unsigned(depth_counter + rounded_index_offset, 7));
					decode_command_pipe_in  <= '1';
					bram_R2_address_pipe_in <= std_logic_vector(to_unsigned(address_offset, p_num_bits));
					store_cmd_pipe_in       <= cmd_store_remainder;
				when loop_one_d =>
					if i < reg_length - 1 then
						state_decode <= loop_if_prep;
					else
						if i = reg_length - 1 then
							state_decode <= loop_finalize;
						else
							state_decode <= next_recursion;
						end if;
					end if;
					bram_br_write_a <= '0';
				when loop_finalize =>
					state_decode <= next_recursion;
				when loop_if_prep =>
					state_decode <= loop_if_case;
					if i = reg_length - 2 then
						i_2_before_end := 1;
					else
						i_2_before_end := 0;
					end if;
					reg_m        <= to_unsigned(M_array_squared_256_16384(depth_counter * 2 + rounded_index_offset + i_2_before_end), 32);
					reg_m2        <= to_unsigned(M_array_squared(depth_counter * 2 + rounded_index_offset + i_2_before_end), 32);

				when loop_if_case =>
					if reg_m = 2 then
						if input_valid = '1' then
							state_decode <= loop_if_one_S0;
							reg_S0       <= input;
						end if;
					elsif reg_m = 1 then
						if input_valid = '1' then
							state_decode <= loop_if_two;
							reg_S0       <= input;
						end if;
					else
						state_decode <= loop_if_three;
					end if;
				when loop_if_one_S0 =>
					if input_valid = '1' then
						state_decode <= loop_if_one_S1;
						reg_S1       <= input;
					end if;
				when loop_if_one_S1 =>
					state_decode <= loop_one_d;
					i            <= i + 2;

					bram_br_data_in_a <= std_logic_vector(unsigned(reg_S0) + shift_left(resize(unsigned(reg_S1), 16), 8));
					bram_br_address_a <= std_logic_vector(to_unsigned(address_offset_next + i / 2, p_num_bits));
					bram_br_write_a   <= '1';
				when loop_if_two =>
					state_decode <= next_loop;

					bram_br_data_in_a <= std_logic_vector(resize(unsigned(reg_S0), 16));
					bram_br_address_a <= std_logic_vector(to_unsigned(address_offset_next + i / 2, p_num_bits));
					bram_br_write_a   <= '1';

				when loop_if_three =>
					state_decode <= next_loop;

					bram_br_data_in_a <= (others => '0');
					bram_br_address_a <= std_logic_vector(to_unsigned(address_offset_next + i / 2, p_num_bits));
					bram_br_write_a   <= '1';

				when next_loop =>
					state_decode <= loop_one_d;
					i            <= i + 2;

					bram_br_write_a <= '0';
				when loop_two_prep =>
					if depth_counter = 1 then
						state_decode <= output_loop;
					else
						state_decode <= loop_two_case;

					end if;

					depth_counter   <= depth_counter - 1;
					bram_R2_write_a <= '0';
					if depth_counter /= 1 then
						address_offset <= address_offset - stack_output;
					else
						address_offset <= 0;
					end if;

					address_offset_next <= address_offset;
					reg_length          <= stack_output;
					pop_stack           <= '1';
					i                   <= 0;
					bram_R2_write_a     <= '0';

					decode_command_pipe_in <= '0';
				when loop_two_case =>
					if i < reg_length - 1 then
						state_decode <= loop_two_wait;
					else
						state_decode <= loop_two_d_end;
					end if;

					bram_br_address_a <= std_logic_vector(to_unsigned(address_offset_next + i / 2, p_num_bits));
					bram_R2_address_a <= std_logic_vector(to_unsigned(address_offset_next + i / 2, p_num_bits));

					pop_stack       <= '0';
					bram_R2_write_a <= '0';
					--bram_R2_write_b <= '0';

					decode_command_pipe_in <= '0';
				when loop_two_wait =>
					state_decode <= loop_two_fma;
				when loop_two_fma =>
					state_decode <= loop_two_divmod;

					if i = reg_length - 2 then
						i_2_before_end := 1;
					else
						i_2_before_end := 0;
					end if;

					if to_unsigned(bottomt_array(depth_counter * 2 + rounded_index_offset + i_2_before_end), 2) = 0 then
						reg_r <= resize(unsigned(bram_br_data_out_a) + unsigned(bram_R2_data_out_a), 32);
					elsif to_unsigned(bottomt_array(depth_counter * 2 + rounded_index_offset + i_2_before_end), 2) = 1 then
						reg_r <= unsigned(bram_br_data_out_a) + shift_left(resize(unsigned(bram_R2_data_out_a), 32), 8);
					else
						reg_r <= unsigned(bram_br_data_out_a) + shift_left(resize(unsigned(bram_R2_data_out_a), 32), 16);
					end if;

					reg_Mi0 <= to_unsigned(M_array(depth_counter + rounded_index_offset), 16);
				when loop_two_divmod =>
					state_decode <= loop_two_store;

					dividend                <= std_logic_vector(reg_r);
					divisor_index           <= std_logic_vector(to_unsigned(depth_counter + rounded_index_offset, 7));
					if i = reg_length - 2 then
						divisor_index_mod <= std_logic_vector(to_unsigned(depth_counter + 11 + rounded_index_offset, 7));
					else
						divisor_index_mod <= std_logic_vector(to_unsigned(depth_counter + rounded_index_offset, 7));
					end if;
					decode_command_pipe_in  <= '1';
					bram_R2_address_pipe_in <= std_logic_vector(to_unsigned(address_offset + i, p_num_bits));
					store_cmd_pipe_in       <= cmd_store_both;
				when loop_two_store =>
					state_decode <= loop_two_case;

					decode_command_pipe_in <= '0';
					i                      <= i + 2;
				when loop_two_d_end =>
					if i = reg_length - 1 then
						state_decode <= loop_two_d_end_write;
					else
						state_decode <= loop_two_flush;
					end if;
					pipe_flush_counter <= 0;
				when loop_two_d_end_write =>
					state_decode      <= loop_two_flush;
					bram_R2_data_in_a <= bram_R2_data_out_a;
					bram_R2_address_a <= std_logic_vector(to_unsigned(address_offset + i, p_num_bits));

					bram_R2_write_a <= '1';
				when loop_two_flush =>
					if pipe_flush_counter = 16 then --TODO this might work with 15
						state_decode <= loop_two_prep;
					end if;
					pipe_flush_counter     <= pipe_flush_counter + 1;
					bram_R2_write_a        <= '0';
					decode_command_pipe_in <= '0';
				when output_loop =>
					if i < reg_length - 1 then
						state_decode <= output_loop_wait;
					else
						state_decode <= output_loop_end;
					end if;
					pop_stack              <= '0';
					decode_command_pipe_in <= '0';
					bram_br_address_a      <= std_logic_vector(to_unsigned(i / 2, p_num_bits));
					bram_R2_address_a      <= std_logic_vector(to_unsigned(i / 2, p_num_bits));
				when output_loop_wait =>
					state_decode <= output_loop_fma;
				when output_loop_fma =>
					state_decode <= output_loop_divmod;

					if i = reg_length - 2 then
						i_2_before_end := 1;
					else
						i_2_before_end := 0;
					end if;

					if to_unsigned(bottomt_array(depth_counter * 2 + rounded_index_offset + i_2_before_end), 2) = 0 then
						reg_r <= resize(unsigned(bram_br_data_out_a) + unsigned(bram_R2_data_out_a), 32);
					elsif to_unsigned(bottomt_array(depth_counter * 2 + rounded_index_offset + i_2_before_end), 2) = 1 then
						reg_r <= unsigned(bram_br_data_out_a) + shift_left(resize(unsigned(bram_R2_data_out_a), 32), 8);
					else
						reg_r <= unsigned(bram_br_data_out_a) + shift_left(resize(unsigned(bram_R2_data_out_a), 32), 16);
					end if;

				when output_loop_divmod =>
					state_decode <= output_loop;

					dividend <= std_logic_vector(reg_r);

					divisor_index <= std_logic_vector(to_unsigned(0 + rounded_index_offset, 7));

					divisor_index_mod <= std_logic_vector(to_unsigned(0 + rounded_index_offset, 7));
					store_cmd_pipe_in <= cmd_output_both;

					decode_command_pipe_in <= '1';
					i                      <= i + 2;
				when output_loop_end =>
					state_decode <= output_loop_end_2;
				when output_loop_end_2 =>
					state_decode <= output_end_write;
				when output_end_write =>
					state_decode       <= output_flush_pipe;
					if i = reg_length - 1 then
						dividend <= std_logic_vector(resize(unsigned(bram_R2_data_out_a), 32));

						divisor_index <= std_logic_vector(to_unsigned(0 + rounded_index_offset, 7));

						divisor_index_mod <= std_logic_vector(to_unsigned(0 + rounded_index_offset, 7));
						store_cmd_pipe_in <= cmd_output_r0_only;

						decode_command_pipe_in <= '1';
					end if;
					pipe_flush_counter <= 0;
				when output_flush_pipe =>
					if pipe_flush_counter = 16 then --TODO this might work with 15
						state_decode <= decode_done;
					end if;
					decode_command_pipe_in <= '0';
					pipe_flush_counter     <= pipe_flush_counter + 1;
				when decode_done =>
					state_decode <= idle;
					done         <= '1';
			end case;
		end if;
	end process fsm_process;

	output_reg : process(clock, reset) is
	begin
		if reset = '1' then
			output_valid  <= '0';
			output_reg_r1 <= '0';
		elsif rising_edge(clock) then
			output_valid <= '0';
			if output_reg_r0 = '1' then
				output       <= std_logic_vector(reg_r0(q_num_bits - 1 downto 0));
				if output_reg_r0_only = '0' then
					output_reg_r1 <= '1';
				end if;
				output_valid <= '1';
			end if;
			if output_reg_r1 = '1' then
				output        <= std_logic_vector(reg_r1(q_num_bits - 1 downto 0));
				output_reg_r1 <= '0';
				output_valid  <= '1';
			end if;

		end if;
	end process output_reg;

	input_ack <= '0' when state_decode = idle
	             else '1' when state_decode = loop_input and i < reg_length - 1 and input_valid = '1'
	             else '1' when state_decode = loop_input_one and input_valid = '1' and rounded_decode = '0'
	             else '1' when state_decode = recursion_end and input_valid = '1' and M_array(depth_counter + rounded_index_offset) /= 1
	             else '1' when state_decode = recursion_end_2 and input_valid = '1' and reg_Mi0 > to_unsigned(256, 16)
	             else '1' when state_decode = loop_if_case and input_valid = '1' and reg_m >= 1
	             else '1' when state_decode = loop_if_one_S0 and input_valid = '1'
	             else '0';

	rounded_index_offset <= 0 when rounded_decode = '0' else 21;

	stack_memory_inst : entity work.stack_memory
		generic map(
			DEPTH => max_depth
		)
		port map(
			clock        => clock,
			reset        => reset,
			push_stack   => push_stack,
			pop_stack    => pop_stack,
			stack_input  => stack_input,
			stack_output => stack_output
		);

	div_mod_pipeline_inst : entity work.div_mod_pipeline(RTL)
		port map(
			clock                    => clock,
			reset                    => reset,
			dividend                 => dividend,
			divisor_index            => divisor_index,
			divisor_index_mod        => divisor_index_mod,
			decode_command_pipe_in   => decode_command_pipe_in,
			bram_R2_address_pipe_in  => bram_R2_address_pipe_in,
			store_cmd_pipe_in        => store_cmd_pipe_in,
			decode_command_pipe_out  => decode_command_pipe_out,
			bram_R2_address_pipe_out => bram_R2_address_pipe_out,
			store_cmd_pipe_out       => store_cmd_pipe_out,
			remainder_mod            => remainder_mod,
			remainder_pipe_delay_out => remainder_pipe_delay_out
		);

	decode_command <= decode_command_pipe_out;

	store_div_result : process(clock, reset) is
	begin
		if reset = '1' then
			reg_store_both     <= '0';
			bram_R2_write_b    <= '0';
			output_reg_r0      <= '0';
			output_reg_r0_only <= '0';
		elsif rising_edge(clock) then
			output_reg_r0      <= '0';
			output_reg_r0_only <= '0';
			bram_R2_write_b    <= '0';

			if decode_command = '1' and reg_store_both = '0' then
				if store_cmd_pipe_out = cmd_output_both then
					reg_r0        <= unsigned(remainder_pipe_delay_out);
					reg_r1        <= unsigned(remainder_mod);
					output_reg_r0 <= '1';
				elsif store_cmd_pipe_out = cmd_output_r0_only then
					reg_r0             <= unsigned(remainder_pipe_delay_out);
					output_reg_r0      <= '1';
					output_reg_r0_only <= '1';
				else
					bram_R2_address_b <= bram_R2_address_pipe_out;
					bram_R2_data_in_b <= remainder_pipe_delay_out;
					bram_R2_write_b   <= '1';
					if store_cmd_pipe_out = cmd_store_both then
						reg_store_address <= bram_R2_address_pipe_out;
						reg_store_both    <= '1';
						reg_remainder_mod <= remainder_mod;
					end if;
				end if;
			elsif reg_store_both = '1' then
				bram_R2_address_b <= std_logic_vector(unsigned(reg_store_address) + 1);
				bram_R2_data_in_b <= reg_remainder_mod;
				bram_R2_write_b   <= '1';
				reg_store_both    <= '0';
			end if;

		end if;
	end process store_div_result;

	block_ram_R2 : entity work.block_ram
		generic map(
			ADDRESS_WIDTH => p_num_bits,
			DATA_WIDTH    => 16
		)
		port map(
			clock      => clock,
			address_a  => bram_R2_address_a,
			write_a    => bram_R2_write_a,
			data_in_a  => bram_R2_data_in_a,
			data_out_a => bram_R2_data_out_a,
			address_b  => bram_R2_address_b,
			write_b    => bram_R2_write_b,
			data_in_b  => bram_R2_data_in_b,
			data_out_b => open
		);

	block_ram_bottomr : entity work.block_ram
		generic map(
			ADDRESS_WIDTH => p_num_bits,
			DATA_WIDTH    => 16
		)
		port map(
			clock      => clock,
			address_a  => bram_br_address_a,
			write_a    => bram_br_write_a,
			data_in_a  => bram_br_data_in_a,
			data_out_a => bram_br_data_out_a,
			address_b  => bram_br_address_b,
			write_b    => bram_br_write_b,
			data_in_b  => bram_br_data_in_b,
			data_out_b => open
		);

	bram_br_address_b <= (others => '0');
	bram_br_data_in_b <= (others => '0');
end architecture RTL;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

-- Generic schoolbook polynomial multiplier, with one rq input and one r3 (2 bit) input

entity rq_mult_generic is
	generic(
		q_num_bits : integer := 13;
		q          : integer := 4591;
		q_half     : integer := 2296;
		p_num_bits : integer := 10;
		p          : integer := 761
	);
	port(
		clock             : in  std_logic;
		reset             : in  std_logic;
		start             : in  std_logic;
		ready             : out std_logic;
		output_valid      : out std_logic;
		output            : out std_logic_vector(q_num_bits - 1 downto 0);
		output_ack        : in  std_logic; -- Unused
		done              : out std_logic;
		bram_f_address_a  : out std_logic_vector(p_num_bits - 1 downto 0);
		bram_f_data_out_a : in  std_logic_vector(q_num_bits - 1 downto 0);
		bram_f_address_b  : out std_logic_vector(p_num_bits - 1 downto 0);
		bram_f_data_out_b : in  std_logic_vector(q_num_bits - 1 downto 0);
		bram_g_address_a  : out std_logic_vector(p_num_bits - 1 downto 0);
		bram_g_data_out_a : in  std_logic_vector(2 - 1 downto 0);
		bram_g_address_b  : out std_logic_vector(p_num_bits - 1 downto 0);
		bram_g_data_out_b : in  std_logic_vector(2 - 1 downto 0)
	);
end entity rq_mult_generic;

architecture RTL of rq_mult_generic is
	constant bram_address_width : integer := p_num_bits + 1;
	constant pipeline_length    : integer := 2;

	signal bram_fg_address_a  : std_logic_vector(bram_address_width - 1 downto 0);
	signal bram_fg_write_a    : std_logic;
	signal bram_fg_data_in_a  : std_logic_vector(q_num_bits - 1 downto 0);
	signal bram_fg_data_out_a : std_logic_vector(q_num_bits - 1 downto 0);
	signal bram_fg_address_b  : std_logic_vector(bram_address_width - 1 downto 0);
	signal bram_fg_write_b    : std_logic;
	signal bram_fg_data_in_b  : std_logic_vector(q_num_bits - 1 downto 0);
	signal bram_fg_data_out_b : std_logic_vector(q_num_bits - 1 downto 0);

	type address_delay is array (pipeline_length downto 0) of std_logic_vector(bram_address_width - 1 downto 0);

	signal bram_fg_address_a_delay : address_delay;
	signal bram_fg_address_b_delay : address_delay;

	signal bram_fg_address_a_final : std_logic_vector(bram_address_width - 1 downto 0);
	signal bram_fg_address_b_final : std_logic_vector(bram_address_width - 1 downto 0);

	signal result_a : signed(q_num_bits - 1 downto 0);
	signal result_b : signed(q_num_bits - 1 downto 0);

	signal reset_result : std_logic_vector(pipeline_length downto 0);

	signal add_result : std_logic_vector(pipeline_length downto 0);

	signal mult_result_a     : signed(q_num_bits + 2 - 1 downto 0);
	signal mult_result_reg_a : signed(q_num_bits + 2 - 1 downto 0);

	signal mult_result_b     : signed(q_num_bits + 2 - 1 downto 0);
	signal mult_result_reg_b : signed(q_num_bits + 2 - 1 downto 0);

	type state_type is (init_state, outer_loop_1, inner_loop_1, wait_1, wait_2, wait_3, wait_4, final_init, final_loop, final_loop_end, done_state);
	signal state_rq_mult : state_type := init_state;

	signal first_final_loop : std_logic;

	signal second_output_loop : std_logic;

begin

	fsm_process : process(clock, reset) is
		variable i_1 : integer range 0 to 2 * p;
		variable j_1 : integer range 0 to 2 * p;

		variable i_2 : integer range 0 to 2 * p;
		variable j_2 : integer range 0 to 2 * p;
	begin
		if reset = '1' then
			state_rq_mult   <= init_state;
			ready           <= '0';
			add_result(0)   <= '0';
			reset_result(0) <= '1';
			output_valid    <= '0';
			done            <= '0';
		elsif rising_edge(clock) then
			case state_rq_mult is
				when init_state =>
					if start = '1' then
						state_rq_mult <= outer_loop_1;
						ready         <= '0';
					else
						ready         <= '1';
						state_rq_mult <= init_state;
					end if;
					i_1             := 0;
					j_1             := 0;
					i_2             := p + p - 2;
					j_2             := p - 1;
					reset_result(0) <= '0';
					done            <= '0';

					first_final_loop   <= '0';
					second_output_loop <= '0';
				when outer_loop_1 =>
					if i_1 < p then
						state_rq_mult <= inner_loop_1;
					else
						state_rq_mult <= wait_1;
					end if;
					reset_result(0) <= '1';
					j_1             := 0;
					j_2             := p - 1;
				when inner_loop_1 =>
					if j_1 <= i_1 then
						state_rq_mult <= inner_loop_1;

						bram_f_address_a <= std_logic_vector(to_unsigned(j_1, p_num_bits));
						bram_g_address_a <= std_logic_vector(to_unsigned(i_1 - j_1, p_num_bits));

						bram_f_address_b <= std_logic_vector(to_unsigned(j_2, p_num_bits));
						bram_g_address_b <= std_logic_vector(to_unsigned(i_2 - j_2, p_num_bits));

						add_result(0) <= '1';

						j_1 := j_1 + 1;
						j_2 := j_2 - 1;
					else
						state_rq_mult <= outer_loop_1;

						bram_fg_address_a_delay(0) <= std_logic_vector(to_unsigned(i_1, bram_address_width));
						bram_fg_address_b_delay(0) <= std_logic_vector(to_unsigned(i_2, bram_address_width));
						add_result(0)              <= '0';

						i_1 := i_1 + 1;
						i_2 := i_2 - 1;
					end if;

					reset_result(0) <= '0';
				when wait_1 =>
					if output_ack = '1' then						
						state_rq_mult <= wait_2;
					end if;
					
					reset_result(0) <= '0';
					output_valid    <= '0';
				when wait_2 =>
					state_rq_mult <= wait_3;
					i_1           := p + p - 2;
				when wait_3 =>
					state_rq_mult           <= wait_4;
				when wait_4 =>
					state_rq_mult           <= final_init;
					bram_fg_address_b_final <= std_logic_vector(to_unsigned(i_1, bram_address_width));
					i_1                     := i_1 - 1;
				when final_init =>
					state_rq_mult           <= final_loop;
					bram_fg_address_b_final <= std_logic_vector(to_unsigned(i_1, bram_address_width));
				when final_loop =>
					if i_1 >= 1 then
						state_rq_mult <= final_loop;
						i_1 := i_1 - 1;
						bram_fg_address_b_final <= std_logic_vector(to_unsigned(i_1, bram_address_width));
					else
						state_rq_mult <= final_loop_end;
					end if;

					output_valid <= '1';
					output       <= std_logic_vector(bram_fg_data_out_b(q_num_bits - 1 downto 0));
				when final_loop_end =>
					if second_output_loop = '1' then
						second_output_loop <= '0';
						state_rq_mult      <= done_state;
					else
						second_output_loop <= '1';
						state_rq_mult      <= wait_1;
					end if;

					output_valid <= '1';
					output       <= std_logic_vector(bram_fg_data_out_b(q_num_bits - 1 downto 0));

				when done_state =>
					state_rq_mult <= init_state;
					output_valid  <= '0';
					done          <= '1';
			end case;
		end if;
	end process fsm_process;

	shift_pipeline : process(clock, reset) is
	begin
		if reset = '1' then
			add_result(pipeline_length downto 1)   <= (others => '0');
			reset_result(pipeline_length downto 1) <= (others => '1');
		elsif rising_edge(clock) then
			add_result(pipeline_length downto 1)              <= add_result(pipeline_length - 1 downto 0);
			reset_result(pipeline_length downto 1)            <= reset_result(pipeline_length - 1 downto 0);
			bram_fg_address_a_delay(pipeline_length downto 1) <= bram_fg_address_a_delay(pipeline_length - 1 downto 0);
			bram_fg_address_b_delay(pipeline_length downto 1) <= bram_fg_address_b_delay(pipeline_length - 1 downto 0);
		end if;
	end process shift_pipeline;

	--mult_result_reg <= signed(bram_g_data_out_a) * signed(bram_f_data_out_a);
	mult_result_reg_a <= resize(signed(bram_f_data_out_a), q_num_bits + 2) when bram_g_data_out_a = "01"
		else resize(0 - signed(bram_f_data_out_a), q_num_bits + 2) when bram_g_data_out_a = "11"
		else (others => '0');

	mult_result_reg_b <= resize(signed(bram_f_data_out_b), q_num_bits + 2) when bram_g_data_out_b = "01"
		else resize(0 - signed(bram_f_data_out_b), q_num_bits + 2) when bram_g_data_out_b = "11"
		else (others => '0');

	assert bram_g_data_out_a /= "10" report "Small element is not small" severity error;

	muklt_process : process(clock, reset) is
	begin
		if reset = '1' then
			mult_result_a <= (others => '0');
			mult_result_b <= (others => '0');
		elsif rising_edge(clock) then
			mult_result_a <= mult_result_reg_a;
			mult_result_b <= mult_result_reg_b;
		end if;
	end process muklt_process;

	add_result_process : process(clock) is
		variable result_a_var : signed(q_num_bits + 2 - 1 downto 0);
		variable result_b_var : signed(q_num_bits + 2 - 1 downto 0);

	begin
		if rising_edge(clock) then
			if reset_result(pipeline_length) = '1' then

				result_a_var := (others => '0');
				result_b_var := (others => '0');
			else
				if add_result(pipeline_length) = '1' then

					result_a_var := result_a + mult_result_a;
					result_b_var := result_b + mult_result_b;

					if result_a_var >= q_half then
						result_a_var := result_a_var - q;
					end if;
					if result_a_var <= -q_half then
						result_a_var := result_a_var + q;
					end if;

					if result_b_var >= q_half then
						result_b_var := result_b_var - q;
					end if;
					if result_b_var <= -q_half then
						result_b_var := result_b_var + q;
					end if;

				end if;
			end if;
			result_a <= result_a_var(q_num_bits - 1 downto 0);
			result_b <= result_b_var(q_num_bits - 1 downto 0);
		end if;
	end process add_result_process;

	bram_fg_data_in_a <= std_logic_vector(result_a);
	bram_fg_data_in_b <= std_logic_vector(result_b);
	bram_fg_write_a   <= reset_result(pipeline_length) when state_rq_mult /= init_state else '0';
	bram_fg_write_b   <= bram_fg_write_a when bram_fg_address_a /= bram_fg_address_b else '0';

	bram_fg_address_a <= bram_fg_address_a_delay(pipeline_length) when state_rq_mult /= final_loop and state_rq_mult /= final_init else bram_fg_address_a_final;
	bram_fg_address_b <= bram_fg_address_b_delay(pipeline_length) when state_rq_mult /= wait_4 and state_rq_mult /= final_loop and state_rq_mult /= final_init else bram_fg_address_b_final;

	block_ram_inst : entity work.block_ram
		generic map(
			ADDRESS_WIDTH => bram_address_width,
			DATA_WIDTH    => q_num_bits
		)
		port map(
			clock      => clock,
			address_a  => bram_fg_address_a,
			write_a    => bram_fg_write_a,
			data_in_a  => bram_fg_data_in_a,
			data_out_a => bram_fg_data_out_a,
			address_b  => bram_fg_address_b,
			write_b    => bram_fg_write_b,
			data_in_b  => bram_fg_data_in_b,
			data_out_b => bram_fg_data_out_b
		);
end architecture RTL;

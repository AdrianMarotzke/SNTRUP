library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.constants.all;
use work.data_type.all;

-- The core decapsulation
entity key_decapsulation is
	port(
		clock                : in  std_logic;
		reset                : in  std_logic;
		start                : in  std_logic;
		done                 : out std_logic;
		output               : out std_logic_vector(1 downto 0);
		output_valid         : out std_logic;
		rq_mult_start        : out std_logic;
		rq_mult_ready        : in  std_logic;
		rq_mult_output_valid : in  std_logic;
		rq_mult_output       : in  std_logic_vector(q_num_bits - 1 downto 0);
		rq_mult_output_ack   : out std_logic;
		rq_mult_done         : in  std_logic;
		bram_ginv_address_a  : out std_logic_vector(p_num_bits - 1 downto 0);
		bram_ginv_data_out_a : in  std_logic_vector(1 downto 0);
		bram_ginv_address_b  : out std_logic_vector(p_num_bits - 1 downto 0);
		bram_ginv_data_out_b : in  std_logic_vector(1 downto 0);
		to_r3_mult           : out rq_multiplication_in_type;
		from_r3_mult         : in  rq_multiplication_out_type;
		to_freeze_round      : out mod3_freeze_round_in_type;
		from_freeze_round    : in  mod3_freeze_round_out_type
	);
end entity key_decapsulation;

architecture RTL of key_decapsulation is

	type state_type is (idle, mult_Rq, mult_freeze, mult_freeze_done, mult_R3, calc_weight, output_masked_weight, done_state);
	signal state_decap : state_type;

	signal rq_mult3_enable       : std_logic;
	signal rq_mult3_input        : std_logic_vector(q_num_bits - 1 downto 0);
	signal rq_mult3_output       : std_logic_vector(q_num_bits - 1 downto 0);
	signal rq_mult3_output_valid : std_logic;

	signal r3_mult_start        : std_logic;
	signal r3_mult_ready        : std_logic;
	signal r3_mult_output_valid : std_logic;
	signal r3_mult_output       : std_logic_vector(1 downto 0);
	signal r3_mult_done         : std_logic;

	signal calc_weight_start             : std_logic;
	signal calc_weight_input             : std_logic_vector(1 downto 0);
	signal calc_weight_input_valid       : std_logic;
	signal calc_weight_mask_output       : std_logic_vector(q_num_bits - 1 downto 0);
	signal calc_weight_mask_output_valid : std_logic;

	signal mod3_freeze_input        : signed(q_num_bits - 1 downto 0);
	signal mod3_freeze_enable       : std_logic;
	signal mod3_freeze_output       : signed(1 downto 0);
	signal mod3_freeze_output_valid : std_logic;

	signal bram_e_address_a  : std_logic_vector(p_num_bits - 1 downto 0);
	signal bram_e_write_a    : std_logic;
	signal bram_e_data_in_a  : std_logic_vector(1 downto 0);
	signal bram_e_data_out_a : std_logic_vector(1 downto 0);
	signal bram_e_address_b  : std_logic_vector(p_num_bits - 1 downto 0);
	signal bram_e_write_b    : std_logic;
	signal bram_e_data_in_b  : std_logic_vector(1 downto 0);
	signal bram_e_data_out_b : std_logic_vector(1 downto 0);

	signal bram_e_address_a_r3 : std_logic_vector(p_num_bits - 1 downto 0);
	signal bram_e_address_b_r3 : std_logic_vector(p_num_bits - 1 downto 0);

	signal bram_e_address_a_fsm : std_logic_vector(p_num_bits - 1 downto 0);

	signal counter : integer range 0 to p;

	signal ev : std_logic_vector(1 downto 0);

begin

	fsm_process : process(clock, reset) is
	begin
		if reset = '1' then
			state_decap       <= idle;
			done              <= '0';
			calc_weight_start <= '0';
			r3_mult_start     <= '0';
			--rq_mult3_enable   <= '0';
			rq_mult_start     <= '0';
			output_valid      <= '0';
		elsif rising_edge(clock) then
			case state_decap is
				when idle =>
					if start = '1' then
						state_decap <= mult_Rq;
					end if;
					counter <= p - 1;
					done    <= '0';
				when mult_Rq =>
					rq_mult_start <= '1';
					if rq_mult_output_valid = '1' then
						state_decap   <= mult_freeze;
						rq_mult_start <= '0';
					end if;

				when mult_freeze =>
					if mod3_freeze_output_valid = '1' then
						counter <= counter - 1;
					end if;
					if rq_mult_done = '1' then
						state_decap <= mult_freeze_done;
					end if;
				when mult_freeze_done =>
					if mod3_freeze_output_valid = '1' then
						counter <= counter - 1;
					end if;
					if mod3_freeze_output_valid = '0' then
						state_decap       <= mult_R3;
						r3_mult_start     <= '1';
						calc_weight_start <= '1';
						counter           <= p - 1;
					end if;
				when mult_R3 =>
					if r3_mult_done = '1' then
						state_decap <= calc_weight;
					end if;

					r3_mult_start     <= '0';
					calc_weight_start <= '0';

					if r3_mult_output_valid = '1' then
						counter <= counter - 1;
					end if;
				when calc_weight =>
					if calc_weight_mask_output_valid = '1' then
						state_decap <= output_masked_weight;
					end if;
					counter <= 0;
				when output_masked_weight =>
					counter      <= counter + 1;
					output_valid <= '1';
					if counter = p then -- To p so final element is also output
						state_decap  <= done_state;
						output_valid <= '0';
					end if;
				when done_state =>
					done <= '1';

					state_decap <= idle;
			end case;
		end if;
	end process fsm_process;

	rq_mult_output_ack  <= '1';

	rq_mult3_input  <= rq_mult_output;
	rq_mult3_enable <= rq_mult_output_valid when state_decap /= mult_R3 and state_decap /= calc_weight else '0';

	mod3_freeze_input  <= signed(rq_mult3_output) when state_decap /= mult_R3 and state_decap /= calc_weight else signed(from_r3_mult.output);
	mod3_freeze_enable <= rq_mult3_output_valid when state_decap /= mult_R3 and state_decap /= calc_weight else from_r3_mult.output_valid;

	bram_e_address_a_fsm <= std_logic_vector(to_unsigned(counter, p_num_bits));
	bram_e_write_a       <= mod3_freeze_output_valid when state_decap /= mult_R3 and state_decap /= calc_weight else r3_mult_output_valid;
	bram_e_data_in_a     <= std_logic_vector(mod3_freeze_output) when state_decap /= mult_R3 and state_decap /= calc_weight else r3_mult_output;

	bram_e_address_a <= bram_e_address_a_fsm when state_decap = mult_freeze or --
	                    state_decap = mult_freeze_done or --
	                    state_decap = output_masked_weight or r3_mult_output_valid = '1' else bram_e_address_a_r3;
	                    
	bram_e_address_b <= bram_e_address_b_r3;

	bram_e_write_b   <= '0';
	bram_e_data_in_b <= (others => '0');

--	bram_e_write_b   <= r3_mult_output_valid;
--	bram_e_data_in_b <= r3_mult_output;
	
	calc_weight_input_valid <= r3_mult_output_valid;
	calc_weight_input       <= r3_mult_output;

	ev     <= bram_e_data_out_a when state_decap = output_masked_weight else (others => '0');
	output <= ((ev xor "01") and not calc_weight_mask_output(1 downto 0)) xor "01" when counter <= 2 * t --
	          else ev and not calc_weight_mask_output(1 downto 0);

	rq_mult3_inst : entity work.rq_mult3
		port map(
			clock        => clock,
			reset        => reset,
			enable       => rq_mult3_enable,
			input        => rq_mult3_input,
			output       => rq_mult3_output,
			output_valid => rq_mult3_output_valid
		);

	to_r3_mult.start             <= r3_mult_start;
	to_r3_mult.output_ack        <= '1';
	to_r3_mult.bram_f_data_out_a <= std_logic_vector(resize(signed(bram_e_data_out_a), q_num_bits));
	to_r3_mult.bram_f_data_out_b <= std_logic_vector(resize(signed(bram_e_data_out_b), q_num_bits));
	to_r3_mult.bram_g_data_out_a <= bram_ginv_data_out_a;
	to_r3_mult.bram_g_data_out_b <= bram_ginv_data_out_b;

	r3_mult_ready       <= from_r3_mult.ready;
	r3_mult_done        <= from_r3_mult.done;
	bram_e_address_a_r3 <= from_r3_mult.bram_f_address_a;
	bram_e_address_b_r3 <= from_r3_mult.bram_f_address_b;
	bram_ginv_address_a <= from_r3_mult.bram_g_address_a;
	bram_ginv_address_b <= from_r3_mult.bram_g_address_b;

	r3_mult_output_valid <= mod3_freeze_output_valid when state_decap = mult_R3 or state_decap = calc_weight else '0';
	r3_mult_output       <= std_logic_vector(mod3_freeze_output);

	calc_weight_inst : entity work.calc_weight
		port map(
			clock             => clock,
			reset             => reset,
			start             => calc_weight_start,
			input             => calc_weight_input,
			input_valid       => calc_weight_input_valid,
			mask_output       => calc_weight_mask_output,
			mask_output_valid => calc_weight_mask_output_valid
		);

	to_freeze_round.input  <= mod3_freeze_input;
	to_freeze_round.enable <= mod3_freeze_enable;

	mod3_freeze_output       <= from_freeze_round.output;
	mod3_freeze_output_valid <= from_freeze_round.output_valid;

	block_ram_inst : entity work.block_ram
		generic map(
			ADDRESS_WIDTH => p_num_bits,
			DATA_WIDTH    => 2
		)
		port map(
			clock      => clock,
			address_a  => bram_e_address_a,
			write_a    => bram_e_write_a,
			data_in_a  => bram_e_data_in_a,
			data_out_a => bram_e_data_out_a,
			address_b  => bram_e_address_b,
			write_b    => bram_e_write_b,
			data_in_b  => bram_e_data_in_b,
			data_out_b => bram_e_data_out_b
		);

end architecture RTL;

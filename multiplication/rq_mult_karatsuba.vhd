library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

--use work.constants.all;

-- Top module for the karatsuba multiplication.
entity rq_mult_karatsuba_2bit is
	generic(
		q_num_bits        : integer := 13;
		q                 : integer := 4591;
		q_half            : integer := 2296;
		p_num_bits        : integer := 10;
		p                 : integer := 761;
		layer_2_karatsuba : boolean := true
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
end entity rq_mult_karatsuba_2bit;

architecture RTL of rq_mult_karatsuba_2bit is
	constant split_address_width : integer := p_num_bits - 1;

	constant m2 : integer := p / 2;

	constant bram_address_result_width : integer := p_num_bits + 1;

	type state_type is (IDLE, PREPARE_RAM, PAUSE, START_MULT, STORE_MULT_Z0, STORE2_MULT_Z0, STORE_MULT_Z1, STORE_MULT_Z2, STORE2_MULT_Z2,
	                    POST_PROCESS, POST_PROCESS_1, POST_PROCESS_2, FINAL_INIT, FINAL_LOOP, FINAL_LOOP_DONE, DONE_STATE
	                   );
	signal state_mult_kar : state_type;

	signal counter_low  : integer range 0 to m2 + 1;
	signal counter_high : integer range m2 to p + 1;

	signal counter_result : integer range 0 to p + p + 1;

	signal bram_write                : std_logic;
	signal lowhigh1_data_in_a        : signed(q_num_bits downto 0);
	signal lowhigh1_data_in_a_freeze : signed(q_num_bits downto 0);

	signal lowhigh2_data_in_a : signed(3 - 1 downto 0);

	signal bram_address_fsm : std_logic_vector(split_address_width - 1 downto 0);

	signal bram_low1_address_a  : STD_LOGIC_VECTOR(split_address_width - 1 downto 0);
	signal bram_low1_write_a    : STD_LOGIC;
	signal bram_low1_data_in_a  : STD_LOGIC_VECTOR(q_num_bits - 1 downto 0);
	signal bram_low1_data_out_a : STD_LOGIC_VECTOR(q_num_bits - 1 downto 0);
	signal bram_low1_address_b  : STD_LOGIC_VECTOR(split_address_width - 1 downto 0);
	signal bram_low1_write_b    : STD_LOGIC;
	signal bram_low1_data_in_b  : STD_LOGIC_VECTOR(q_num_bits - 1 downto 0);
	signal bram_low1_data_out_b : STD_LOGIC_VECTOR(q_num_bits - 1 downto 0);

	signal bram_high1_address_a  : STD_LOGIC_VECTOR(split_address_width - 1 downto 0);
	signal bram_high1_write_a    : STD_LOGIC;
	signal bram_high1_data_in_a  : STD_LOGIC_VECTOR(q_num_bits - 1 downto 0);
	signal bram_high1_data_out_a : STD_LOGIC_VECTOR(q_num_bits - 1 downto 0);
	signal bram_high1_address_b  : STD_LOGIC_VECTOR(split_address_width - 1 downto 0);
	signal bram_high1_write_b    : STD_LOGIC;
	signal bram_high1_data_in_b  : STD_LOGIC_VECTOR(q_num_bits - 1 downto 0);
	signal bram_high1_data_out_b : STD_LOGIC_VECTOR(q_num_bits - 1 downto 0);

	signal bram_low2_address_a  : STD_LOGIC_VECTOR(split_address_width - 1 downto 0);
	signal bram_low2_write_a    : STD_LOGIC;
	signal bram_low2_data_in_a  : STD_LOGIC_VECTOR(2 - 1 downto 0);
	signal bram_low2_data_out_a : STD_LOGIC_VECTOR(2 - 1 downto 0);
	signal bram_low2_address_b  : STD_LOGIC_VECTOR(split_address_width - 1 downto 0);
	signal bram_low2_write_b    : STD_LOGIC;
	signal bram_low2_data_in_b  : STD_LOGIC_VECTOR(2 - 1 downto 0);
	signal bram_low2_data_out_b : STD_LOGIC_VECTOR(2 - 1 downto 0);

	signal bram_high2_address_a  : STD_LOGIC_VECTOR(split_address_width - 1 downto 0);
	signal bram_high2_write_a    : STD_LOGIC;
	signal bram_high2_data_in_a  : STD_LOGIC_VECTOR(2 - 1 downto 0);
	signal bram_high2_data_out_a : STD_LOGIC_VECTOR(2 - 1 downto 0);
	signal bram_high2_address_b  : STD_LOGIC_VECTOR(split_address_width - 1 downto 0);
	signal bram_high2_write_b    : STD_LOGIC;
	signal bram_high2_data_in_b  : STD_LOGIC_VECTOR(2 - 1 downto 0);
	signal bram_high2_data_out_b : STD_LOGIC_VECTOR(2 - 1 downto 0);

	signal bram_lowhigh1_address_a  : STD_LOGIC_VECTOR(split_address_width - 1 downto 0);
	signal bram_lowhigh1_write_a    : STD_LOGIC;
	signal bram_lowhigh1_data_in_a  : STD_LOGIC_VECTOR(q_num_bits - 1 downto 0);
	signal bram_lowhigh1_data_out_a : STD_LOGIC_VECTOR(q_num_bits - 1 downto 0);
	signal bram_lowhigh1_address_b  : STD_LOGIC_VECTOR(split_address_width - 1 downto 0);
	signal bram_lowhigh1_write_b    : STD_LOGIC;
	signal bram_lowhigh1_data_in_b  : STD_LOGIC_VECTOR(q_num_bits - 1 downto 0);
	signal bram_lowhigh1_data_out_b : STD_LOGIC_VECTOR(q_num_bits - 1 downto 0);

	signal bram_lowhigh2_address_a  : STD_LOGIC_VECTOR(split_address_width - 1 downto 0);
	signal bram_lowhigh2_write_a    : STD_LOGIC;
	signal bram_lowhigh2_data_in_a  : STD_LOGIC_VECTOR(3 - 1 downto 0);
	signal bram_lowhigh2_data_out_a : STD_LOGIC_VECTOR(3 - 1 downto 0);
	signal bram_lowhigh2_address_b  : STD_LOGIC_VECTOR(split_address_width - 1 downto 0);
	signal bram_lowhigh2_write_b    : STD_LOGIC;
	signal bram_lowhigh2_data_in_b  : STD_LOGIC_VECTOR(3 - 1 downto 0);
	signal bram_lowhigh2_data_out_b : STD_LOGIC_VECTOR(3 - 1 downto 0);

	signal mult_z0_start             : std_logic;
	signal mult_z0_ready             : std_logic;
	signal mult_z0_output_valid      : std_logic;
	signal mult_z0_output            : std_logic_vector(q_num_bits - 1 downto 0);
	signal mult_z0_output_ack        : std_logic;
	signal mult_z0_done              : std_logic;
	signal mult_z0_bram_f_address_a  : std_logic_vector(split_address_width - 1 downto 0);
	signal mult_z0_bram_f_data_out_a : std_logic_vector(q_num_bits - 1 downto 0);
	signal mult_z0_bram_f_address_b  : std_logic_vector(split_address_width - 1 downto 0);
	signal mult_z0_bram_f_data_out_b : std_logic_vector(q_num_bits - 1 downto 0);
	signal mult_z0_bram_g_address_a  : std_logic_vector(split_address_width - 1 downto 0);
	signal mult_z0_bram_g_data_out_a : std_logic_vector(2 - 1 downto 0);
	signal mult_z0_bram_g_address_b  : std_logic_vector(split_address_width - 1 downto 0);
	signal mult_z0_bram_g_data_out_b : std_logic_vector(2 - 1 downto 0);

	signal mult_z1_start             : std_logic;
	signal mult_z1_ready             : std_logic;
	signal mult_z1_output_valid      : std_logic;
	signal mult_z1_output            : std_logic_vector(q_num_bits - 1 downto 0);
	signal mult_z1_output_ack        : std_logic;
	signal mult_z1_done              : std_logic;
	signal mult_z1_bram_f_address_a  : std_logic_vector(split_address_width - 1 downto 0);
	signal mult_z1_bram_f_data_out_a : std_logic_vector(q_num_bits - 1 downto 0);
	signal mult_z1_bram_f_address_b  : std_logic_vector(split_address_width - 1 downto 0);
	signal mult_z1_bram_f_data_out_b : std_logic_vector(q_num_bits - 1 downto 0);
	signal mult_z1_bram_g_address_a  : std_logic_vector(split_address_width - 1 downto 0);
	signal mult_z1_bram_g_data_out_a : std_logic_vector(3 - 1 downto 0);
	signal mult_z1_bram_g_address_b  : std_logic_vector(split_address_width - 1 downto 0);
	signal mult_z1_bram_g_data_out_b : std_logic_vector(3 - 1 downto 0);

	signal mult_z2_start             : std_logic;
	signal mult_z2_ready             : std_logic;
	signal mult_z2_output_valid      : std_logic;
	signal mult_z2_output            : std_logic_vector(q_num_bits - 1 downto 0);
	signal mult_z2_output_ack        : std_logic;
	signal mult_z2_done              : std_logic;
	signal mult_z2_bram_f_address_a  : std_logic_vector(split_address_width - 1 downto 0);
	signal mult_z2_bram_f_data_out_a : std_logic_vector(q_num_bits - 1 downto 0);
	signal mult_z2_bram_f_address_b  : std_logic_vector(split_address_width - 1 downto 0);
	signal mult_z2_bram_f_data_out_b : std_logic_vector(q_num_bits - 1 downto 0);
	signal mult_z2_bram_g_address_a  : std_logic_vector(split_address_width - 1 downto 0);
	signal mult_z2_bram_g_data_out_a : std_logic_vector(2 - 1 downto 0);
	signal mult_z2_bram_g_address_b  : std_logic_vector(split_address_width - 1 downto 0);
	signal mult_z2_bram_g_data_out_b : std_logic_vector(2 - 1 downto 0);

	signal bram_result_address_a  : STD_LOGIC_VECTOR(bram_address_result_width - 1 downto 0);
	signal bram_result_write_a    : STD_LOGIC;
	signal bram_result_data_in_a  : STD_LOGIC_VECTOR(q_num_bits - 1 downto 0);
	signal bram_result_data_out_a : STD_LOGIC_VECTOR(q_num_bits - 1 downto 0);
	signal bram_result_address_b  : STD_LOGIC_VECTOR(bram_address_result_width - 1 downto 0);
	signal bram_result_write_b    : STD_LOGIC;
	signal bram_result_data_in_b  : STD_LOGIC_VECTOR(q_num_bits - 1 downto 0);
	signal bram_result_data_out_b : STD_LOGIC_VECTOR(q_num_bits - 1 downto 0);

	signal result_pre_freeze  : std_logic_vector(q_num_bits downto 0);
	signal result_post_freeze : std_logic_vector(q_num_bits downto 0);

	signal bram_f_data_out_a_delay : std_logic_vector(q_num_bits - 1 downto 0);
	signal bram_g_data_out_a_delay : std_logic_vector(2 - 1 downto 0);

	signal bram_result_address_a_final : std_logic_vector(bram_address_result_width - 1 downto 0);
	signal bram_result_address_b_final : std_logic_vector(bram_address_result_width - 1 downto 0);

	signal result_reduce_temp : signed(q_num_bits - 1 downto 0);
begin

	fsm_process : process(clock, reset) is
		variable output_var             : signed(q_num_bits downto 0);
		variable result_reduce_temp_var : signed(q_num_bits downto 0);
	begin
		if reset = '1' then
			state_mult_kar     <= IDLE;
			ready              <= '0';
			done               <= '0';
			bram_write         <= '0';
			mult_z0_start      <= '0';
			mult_z1_start      <= '0';
			mult_z2_start      <= '0';
			mult_z0_output_ack <= '0';
			mult_z1_output_ack <= '0';
			mult_z2_output_ack <= '0';
			output_valid       <= '0';
		elsif rising_edge(clock) then
			case state_mult_kar is
				when IDLE =>
					if start = '1' then
						state_mult_kar <= PREPARE_RAM;
						counter_low    <= 0;
						counter_high   <= m2;
					end if;

					ready        <= '1';
					done         <= '0';
					output_valid <= '0';
				when PREPARE_RAM =>
					if counter_low = m2 then
						state_mult_kar <= PAUSE;

					end if;
					counter_low  <= counter_low + 1;
					counter_high <= counter_high + 1;
					bram_write   <= '1';
					ready        <= '0';
				when PAUSE =>
					state_mult_kar <= START_MULT;
					bram_write     <= '0';
					mult_z0_start  <= '1';
					mult_z1_start  <= '1';
					mult_z2_start  <= '1';
					counter_result <= 0;
				when START_MULT =>

					if counter_result < p + p + 1 then
						counter_result <= counter_result + 1;
					else
						state_mult_kar <= STORE_MULT_Z0;
						counter_result <= p - 3;
					end if;

					mult_z0_start <= '0';
					mult_z1_start <= '0';
					mult_z2_start <= '0';
				when STORE_MULT_Z0 =>
					if mult_z0_output_valid = '1' then
						counter_result <= counter_result - 1;

					end if;

					if counter_result = 0 then
						counter_result <= m2 + p - 2;
						state_mult_kar <= STORE2_MULT_Z0;
					end if;
					mult_z0_output_ack <= '1';
				when STORE2_MULT_Z0 =>
					if mult_z0_done = '1' then
						state_mult_kar     <= STORE_MULT_Z1;
						counter_result     <= m2 + p - 2;
						mult_z1_output_ack <= '1';
						mult_z0_output_ack <= '0';
					end if;

					if mult_z0_output_valid = '1' then
						counter_result <= counter_result - 1;

					end if;
				when STORE_MULT_Z1 =>
					if mult_z1_output_valid = '1' then
						counter_result <= counter_result - 1;

					end if;

					if counter_result = m2 - 1 then
						state_mult_kar     <= STORE_MULT_Z2;
						mult_z2_output_ack <= '1';
						mult_z1_output_ack <= '0';
						counter_result     <= 2 * m2 + p - 1;
					end if;
				when STORE_MULT_Z2 =>
					if mult_z2_output_valid = '1' then
						counter_result <= counter_result - 1;

					end if;

					if counter_result = 2 * m2 then
						counter_result <= m2 + p - 2;
						state_mult_kar <= STORE2_MULT_Z2;
					end if;
				when STORE2_MULT_Z2 =>
					if mult_z2_done = '1' then
						state_mult_kar     <= POST_PROCESS;
						mult_z2_output_ack <= '0';
					end if;

					if mult_z2_output_valid = '1' then
						counter_result <= counter_result - 1;

					end if;
				when POST_PROCESS =>
					counter_result <= p + p - 2;
					if output_ack = '1' then
						state_mult_kar <= POST_PROCESS_1;
					end if;
				when POST_PROCESS_1 =>
					state_mult_kar              <= POST_PROCESS_2;
					bram_result_address_b_final <= std_logic_vector(to_unsigned(counter_result - p + 1, bram_address_result_width));
				when POST_PROCESS_2 =>
					state_mult_kar              <= FINAL_INIT;
					bram_result_address_a_final <= std_logic_vector(to_unsigned(counter_result - p, bram_address_result_width));
					bram_result_address_b_final <= std_logic_vector(to_unsigned(counter_result, bram_address_result_width));
					counter_result              <= counter_result - 1;
				when FINAL_INIT =>
					result_reduce_temp          <= signed(bram_result_data_out_b);
					state_mult_kar              <= FINAL_LOOP;
					bram_result_address_a_final <= std_logic_vector(to_unsigned(counter_result - p, bram_address_result_width));
					bram_result_address_b_final <= std_logic_vector(to_unsigned(counter_result, bram_address_result_width));
				when FINAL_LOOP =>
					result_reduce_temp_var := resize(signed(bram_result_data_out_a), q_num_bits + 1) + signed(bram_result_data_out_b);
					if result_reduce_temp_var > q_half then
						result_reduce_temp_var := result_reduce_temp_var - q;
					elsif result_reduce_temp_var < -q_half then
						result_reduce_temp_var := result_reduce_temp_var + q;
					else
						result_reduce_temp_var := result_reduce_temp_var;
					end if;
					result_reduce_temp     <= result_reduce_temp_var(q_num_bits - 1 downto 0);

					if counter_result >= p then
						state_mult_kar <= FINAL_LOOP;

						counter_result <= counter_result - 1;

						bram_result_address_a_final <= std_logic_vector(to_unsigned(counter_result - 1 - p, bram_address_result_width));
						bram_result_address_b_final <= std_logic_vector(to_unsigned(counter_result - 1, bram_address_result_width));

					else
						state_mult_kar <= FINAL_LOOP_DONE;
					end if;

					output_var := resize(result_reduce_temp, q_num_bits + 1) + signed(bram_result_data_out_b);
					if output_var >= q_half then
						output_var := (output_var - q);
					elsif output_var <= -q_half then
						output_var := (output_var + q);
					else
						output_var := (output_var);
					end if;

					output_valid <= '1';
					output       <= std_logic_vector(output_var(q_num_bits - 1 downto 0));
				when FINAL_LOOP_DONE =>
					state_mult_kar <= DONE_STATE;
					output_valid   <= '1';
					output         <= std_logic_vector(result_reduce_temp_var(q_num_bits - 1 downto 0));
				when DONE_STATE =>
					state_mult_kar <= IDLE;
					output_valid   <= '0';
					done           <= '1';
			end case;
		end if;
	end process fsm_process;

	bram_f_address_a <= std_logic_vector(to_unsigned(counter_low, p_num_bits));
	bram_f_address_b <= std_logic_vector(to_unsigned(counter_high, p_num_bits));
	bram_g_address_a <= std_logic_vector(to_unsigned(counter_low, p_num_bits));
	bram_g_address_b <= std_logic_vector(to_unsigned(counter_high, p_num_bits));

	bram_address_fsm <= std_logic_vector(to_unsigned(counter_low - 1, split_address_width));

	bram_low1_address_a       <= bram_address_fsm when state_mult_kar = PREPARE_RAM or state_mult_kar = PAUSE else mult_z0_bram_f_address_a;
	bram_low1_address_b       <= mult_z0_bram_f_address_b;
	mult_z0_bram_f_data_out_a <= bram_low1_data_out_a;
	mult_z0_bram_f_data_out_b <= bram_low1_data_out_b;

	bram_high1_address_a      <= bram_address_fsm when state_mult_kar = PREPARE_RAM or state_mult_kar = PAUSE else mult_z2_bram_f_address_a;
	bram_high1_address_b      <= mult_z2_bram_f_address_b;
	mult_z2_bram_f_data_out_a <= bram_high1_data_out_a;
	mult_z2_bram_f_data_out_b <= bram_high1_data_out_b;

	bram_low2_address_a       <= bram_address_fsm when state_mult_kar = PREPARE_RAM or state_mult_kar = PAUSE else mult_z0_bram_g_address_a;
	bram_low2_address_b       <= mult_z0_bram_g_address_b;
	mult_z0_bram_g_data_out_a <= bram_low2_data_out_a;
	mult_z0_bram_g_data_out_b <= bram_low2_data_out_b;

	bram_high2_address_a      <= bram_address_fsm when state_mult_kar = PREPARE_RAM or state_mult_kar = PAUSE else mult_z2_bram_g_address_a;
	bram_high2_address_b      <= mult_z2_bram_g_address_b;
	mult_z2_bram_g_data_out_a <= bram_high2_data_out_a;
	mult_z2_bram_g_data_out_b <= bram_high2_data_out_b;

	bram_lowhigh1_address_a   <= bram_address_fsm when state_mult_kar = PREPARE_RAM or state_mult_kar = PAUSE else mult_z1_bram_f_address_a;
	bram_lowhigh1_address_b   <= mult_z1_bram_f_address_b;
	mult_z1_bram_f_data_out_a <= bram_lowhigh1_data_out_a;
	mult_z1_bram_f_data_out_b <= bram_lowhigh1_data_out_b;

	bram_lowhigh2_address_a   <= bram_address_fsm when state_mult_kar = PREPARE_RAM or state_mult_kar = PAUSE else mult_z1_bram_g_address_a;
	bram_lowhigh2_address_b   <= mult_z1_bram_g_address_b;
	mult_z1_bram_g_data_out_a <= bram_lowhigh2_data_out_a;
	mult_z1_bram_g_data_out_b <= bram_lowhigh2_data_out_b;

	bram_low1_data_in_a  <= bram_f_data_out_a;
	bram_high1_data_in_a <= bram_f_data_out_b;

	bram_f_data_out_a_delay <= bram_f_data_out_a when rising_edge(clock);

	-- First element is not added, as  the polynomials have different degrees.
	lowhigh1_data_in_a        <= resize(signed(bram_f_data_out_a_delay), q_num_bits + 1) + signed(bram_f_data_out_b) when counter_low /= 1 else resize(signed(bram_f_data_out_b), q_num_bits + 1);
	lowhigh1_data_in_a_freeze <= lowhigh1_data_in_a - q when lowhigh1_data_in_a > q_half
	                             else lowhigh1_data_in_a + q when lowhigh1_data_in_a < -q_half
	                             else lowhigh1_data_in_a;
	bram_lowhigh1_data_in_a   <= std_logic_vector(lowhigh1_data_in_a_freeze(q_num_bits - 1 downto 0));

	bram_low2_data_in_a  <= bram_g_data_out_a;
	bram_high2_data_in_a <= bram_g_data_out_b;

	bram_g_data_out_a_delay <= bram_g_data_out_a when rising_edge(clock);

	lowhigh2_data_in_a <= resize(signed(bram_g_data_out_a_delay), 3) + signed(bram_g_data_out_b);

	bram_lowhigh2_data_in_a <= std_logic_vector(lowhigh2_data_in_a) when counter_low /= 1 else std_logic_vector(resize(signed(bram_g_data_out_b), 3));

	bram_low1_write_a     <= bram_write when counter_low /= p / 2 + 1 else '0';
	bram_low1_write_b     <= '0';
	bram_high1_write_a    <= bram_write;
	bram_high1_write_b    <= '0';
	bram_low2_write_a     <= bram_write when counter_low /= p / 2 + 1 else '0';
	bram_low2_write_b     <= '0';
	bram_high2_write_a    <= bram_write;
	bram_high2_write_b    <= '0';
	bram_lowhigh1_write_a <= bram_write;
	bram_lowhigh1_write_b <= '0';
	bram_lowhigh2_write_a <= bram_write;
	bram_lowhigh2_write_b <= '0';

	bram_result_address_a <= std_logic_vector(to_unsigned(counter_result, bram_address_result_width)) when state_mult_kar = START_MULT
	                         else std_logic_vector(to_unsigned(counter_result - 1, bram_address_result_width)) when mult_z0_output_valid = '1' and (state_mult_kar = STORE_MULT_Z0 or state_mult_kar = STORE2_MULT_Z0)
	                         else std_logic_vector(to_unsigned(counter_result - 1, bram_address_result_width)) when mult_z1_output_valid = '1' and (state_mult_kar = STORE_MULT_Z1)
	                         else std_logic_vector(to_unsigned(counter_result - 1, bram_address_result_width)) when mult_z2_output_valid = '1' and (state_mult_kar = STORE_MULT_Z2 or state_mult_kar = STORE2_MULT_Z2)
	                         else bram_result_address_a_final when state_mult_kar = POST_PROCESS_1 or state_mult_kar = POST_PROCESS_2 or state_mult_kar = FINAL_INIT or state_mult_kar = FINAL_LOOP
	                         else std_logic_vector(to_unsigned(counter_result, bram_address_result_width));

	bram_result_data_in_a <= (others => '0');

	bram_result_write_a <= '1' when state_mult_kar = START_MULT else '0';

	bram_result_address_b <= bram_result_address_b_final when state_mult_kar = POST_PROCESS_1 or state_mult_kar = POST_PROCESS_2 or state_mult_kar = FINAL_INIT or state_mult_kar = FINAL_LOOP else std_logic_vector(to_unsigned(counter_result, bram_address_result_width));

	result_pre_freeze <= std_logic_vector(resize(signed(bram_result_data_out_a), q_num_bits + 1) + signed(mult_z0_output)) when state_mult_kar = STORE_MULT_Z0
	                     else std_logic_vector(resize(signed(bram_result_data_out_a), q_num_bits + 1) - signed(mult_z0_output)) when state_mult_kar = STORE2_MULT_Z0
	                     else std_logic_vector(resize(signed(bram_result_data_out_a), q_num_bits + 1) + signed(mult_z1_output)) when state_mult_kar = STORE_MULT_Z1
	                     else std_logic_vector(resize(signed(bram_result_data_out_a), q_num_bits + 1) + signed(mult_z2_output)) when state_mult_kar = STORE_MULT_Z2
	                     else std_logic_vector(resize(signed(bram_result_data_out_a), q_num_bits + 1) - signed(mult_z2_output)) when state_mult_kar = STORE2_MULT_Z2
	                     else (others => '0');

	result_post_freeze <= std_logic_vector(signed(result_pre_freeze) + q) when (signed(result_pre_freeze) < -q_half)
	                      else std_logic_vector(signed(result_pre_freeze) - q) when (signed(result_pre_freeze) > q_half)
	                      else result_pre_freeze;

	bram_result_data_in_b <= result_post_freeze(q_num_bits - 1 downto 0);

	bram_result_write_b <= '1' when mult_z0_output_valid = '1' and (state_mult_kar = STORE_MULT_Z0 or state_mult_kar = STORE2_MULT_Z0)
	                       else '1' when mult_z1_output_valid = '1' and (state_mult_kar = STORE_MULT_Z1)
	                       else '1' when mult_z2_output_valid = '1' and (state_mult_kar = STORE_MULT_Z2 or state_mult_kar = STORE2_MULT_Z2)
	                       else '0';

	block_ram_low1 : entity work.block_ram
		generic map(
			ADDRESS_WIDTH => split_address_width,
			DATA_WIDTH    => q_num_bits
		)
		port map(
			clock      => clock,
			address_a  => bram_low1_address_a,
			write_a    => bram_low1_write_a,
			data_in_a  => bram_low1_data_in_a,
			data_out_a => bram_low1_data_out_a,
			address_b  => bram_low1_address_b,
			write_b    => bram_low1_write_b,
			data_in_b  => bram_low1_data_in_b,
			data_out_b => bram_low1_data_out_b
		);
	block_ram_high1 : entity work.block_ram
		generic map(
			ADDRESS_WIDTH => split_address_width,
			DATA_WIDTH    => q_num_bits
		)
		port map(
			clock      => clock,
			address_a  => bram_high1_address_a,
			write_a    => bram_high1_write_a,
			data_in_a  => bram_high1_data_in_a,
			data_out_a => bram_high1_data_out_a,
			address_b  => bram_high1_address_b,
			write_b    => bram_high1_write_b,
			data_in_b  => bram_high1_data_in_b,
			data_out_b => bram_high1_data_out_b
		);
	block_ram_low2 : entity work.block_ram
		generic map(
			ADDRESS_WIDTH => split_address_width,
			DATA_WIDTH    => 2
		)
		port map(
			clock      => clock,
			address_a  => bram_low2_address_a,
			write_a    => bram_low2_write_a,
			data_in_a  => bram_low2_data_in_a,
			data_out_a => bram_low2_data_out_a,
			address_b  => bram_low2_address_b,
			write_b    => bram_low2_write_b,
			data_in_b  => bram_low2_data_in_b,
			data_out_b => bram_low2_data_out_b
		);
	block_ram_high2 : entity work.block_ram
		generic map(
			ADDRESS_WIDTH => split_address_width,
			DATA_WIDTH    => 2
		)
		port map(
			clock      => clock,
			address_a  => bram_high2_address_a,
			write_a    => bram_high2_write_a,
			data_in_a  => bram_high2_data_in_a,
			data_out_a => bram_high2_data_out_a,
			address_b  => bram_high2_address_b,
			write_b    => bram_high2_write_b,
			data_in_b  => bram_high2_data_in_b,
			data_out_b => bram_high2_data_out_b
		);
	block_ram_lowhigh1 : entity work.block_ram
		generic map(
			ADDRESS_WIDTH => split_address_width,
			DATA_WIDTH    => q_num_bits
		)
		port map(
			clock      => clock,
			address_a  => bram_lowhigh1_address_a,
			write_a    => bram_lowhigh1_write_a,
			data_in_a  => bram_lowhigh1_data_in_a,
			data_out_a => bram_lowhigh1_data_out_a,
			address_b  => bram_lowhigh1_address_b,
			write_b    => bram_lowhigh1_write_b,
			data_in_b  => bram_lowhigh1_data_in_b,
			data_out_b => bram_lowhigh1_data_out_b
		);
	block_ram_lowhigh2 : entity work.block_ram
		generic map(
			ADDRESS_WIDTH => split_address_width,
			DATA_WIDTH    => 3
		)
		port map(
			clock      => clock,
			address_a  => bram_lowhigh2_address_a,
			write_a    => bram_lowhigh2_write_a,
			data_in_a  => bram_lowhigh2_data_in_a,
			data_out_a => bram_lowhigh2_data_out_a,
			address_b  => bram_lowhigh2_address_b,
			write_b    => bram_lowhigh2_write_b,
			data_in_b  => bram_lowhigh2_data_in_b,
			data_out_b => bram_lowhigh2_data_out_b
		);

	gen_2nd_layer_karatsuba : if layer_2_karatsuba generate
		rq_mult_karatsuba_2bit_inst : entity work.rq_mult_karatsuba_2bit_2nd_layer
			generic map(
				q_num_bits => q_num_bits,
				q          => q,
				q_half     => q_half,
				p_num_bits => split_address_width,
				p          => p / 2
			)
			port map(
				clock             => clock,
				reset             => reset,
				start             => mult_z0_start,
				ready             => mult_z0_ready,
				output_valid      => mult_z0_output_valid,
				output            => mult_z0_output,
				output_ack        => mult_z0_output_ack,
				done              => mult_z0_done,
				bram_f_address_a  => mult_z0_bram_f_address_a,
				bram_f_data_out_a => mult_z0_bram_f_data_out_a,
				bram_f_address_b  => mult_z0_bram_f_address_b,
				bram_f_data_out_b => mult_z0_bram_f_data_out_b,
				bram_g_address_a  => mult_z0_bram_g_address_a,
				bram_g_data_out_a => mult_z0_bram_g_data_out_a,
				bram_g_address_b  => mult_z0_bram_g_address_b,
				bram_g_data_out_b => mult_z0_bram_g_data_out_b
			);

		rq_mult_karatsuba_3bit_2nd_layer_z1 : entity work.rq_mult_karatsuba_3bit_2nd_layer
			generic map(
				q_num_bits => q_num_bits,
				q          => q,
				q_half     => q_half,
				p_num_bits => split_address_width,
				p          => p / 2 + 1
			)
			port map(
				clock             => clock,
				reset             => reset,
				start             => mult_z1_start,
				ready             => mult_z1_ready,
				output_valid      => mult_z1_output_valid,
				output            => mult_z1_output,
				output_ack        => mult_z1_output_ack,
				done              => mult_z1_done,
				bram_f_address_a  => mult_z1_bram_f_address_a,
				bram_f_data_out_a => mult_z1_bram_f_data_out_a,
				bram_f_address_b  => mult_z1_bram_f_address_b,
				bram_f_data_out_b => mult_z1_bram_f_data_out_b,
				bram_g_address_a  => mult_z1_bram_g_address_a,
				bram_g_data_out_a => mult_z1_bram_g_data_out_a,
				bram_g_address_b  => mult_z1_bram_g_address_b,
				bram_g_data_out_b => mult_z1_bram_g_data_out_b
			);

		rq_mult_karatsuba_2bit_2nd_layer_z2 : entity work.rq_mult_karatsuba_2bit_2nd_layer
			generic map(
				q_num_bits => q_num_bits,
				q          => q,
				q_half     => q_half,
				p_num_bits => split_address_width,
				p          => p / 2 + 1
			)
			port map(
				clock             => clock,
				reset             => reset,
				start             => mult_z2_start,
				ready             => mult_z2_ready,
				output_valid      => mult_z2_output_valid,
				output            => mult_z2_output,
				output_ack        => mult_z2_output_ack,
				done              => mult_z2_done,
				bram_f_address_a  => mult_z2_bram_f_address_a,
				bram_f_data_out_a => mult_z2_bram_f_data_out_a,
				bram_f_address_b  => mult_z2_bram_f_address_b,
				bram_f_data_out_b => mult_z2_bram_f_data_out_b,
				bram_g_address_a  => mult_z2_bram_g_address_a,
				bram_g_data_out_a => mult_z2_bram_g_data_out_a,
				bram_g_address_b  => mult_z2_bram_g_address_b,
				bram_g_data_out_b => mult_z2_bram_g_data_out_b
			);
	end generate gen_2nd_layer_karatsuba;

	gen_schoolbook_mult : if NOT layer_2_karatsuba generate
		rq_mult_generic_z0 : entity work.rq_mult_generic
			generic map(
				q_num_bits => q_num_bits,
				q          => q,
				q_half     => q_half,
				p_num_bits => split_address_width,
				p          => p / 2
			)
			port map(
				clock             => clock,
				reset             => reset,
				start             => mult_z0_start,
				ready             => mult_z0_ready,
				output_valid      => mult_z0_output_valid,
				output            => mult_z0_output,
				output_ack        => mult_z0_output_ack,
				done              => mult_z0_done,
				bram_f_address_a  => mult_z0_bram_f_address_a,
				bram_f_data_out_a => mult_z0_bram_f_data_out_a,
				bram_f_address_b  => mult_z0_bram_f_address_b,
				bram_f_data_out_b => mult_z0_bram_f_data_out_b,
				bram_g_address_a  => mult_z0_bram_g_address_a,
				bram_g_data_out_a => mult_z0_bram_g_data_out_a,
				bram_g_address_b  => mult_z0_bram_g_address_b,
				bram_g_data_out_b => mult_z0_bram_g_data_out_b
			);

		rq_mult_generic_z1 : entity work.rq_mult_generic_3bit
			generic map(
				q_num_bits => q_num_bits,
				q          => q,
				q_half     => q_half,
				p_num_bits => split_address_width,
				p          => p / 2 + 1
			)
			port map(
				clock             => clock,
				reset             => reset,
				start             => mult_z1_start,
				ready             => mult_z1_ready,
				output_valid      => mult_z1_output_valid,
				output            => mult_z1_output,
				output_ack        => mult_z1_output_ack,
				done              => mult_z1_done,
				bram_f_address_a  => mult_z1_bram_f_address_a,
				bram_f_data_out_a => mult_z1_bram_f_data_out_a,
				bram_f_address_b  => mult_z1_bram_f_address_b,
				bram_f_data_out_b => mult_z1_bram_f_data_out_b,
				bram_g_address_a  => mult_z1_bram_g_address_a,
				bram_g_data_out_a => mult_z1_bram_g_data_out_a,
				bram_g_address_b  => mult_z1_bram_g_address_b,
				bram_g_data_out_b => mult_z1_bram_g_data_out_b
			);

		rq_mult_generic_z2 : entity work.rq_mult_generic
			generic map(
				q_num_bits => q_num_bits,
				q          => q,
				q_half     => q_half,
				p_num_bits => split_address_width,
				p          => p / 2 + 1
			)
			port map(
				clock             => clock,
				reset             => reset,
				start             => mult_z2_start,
				ready             => mult_z2_ready,
				output_valid      => mult_z2_output_valid,
				output            => mult_z2_output,
				output_ack        => mult_z2_output_ack,
				done              => mult_z2_done,
				bram_f_address_a  => mult_z2_bram_f_address_a,
				bram_f_data_out_a => mult_z2_bram_f_data_out_a,
				bram_f_address_b  => mult_z2_bram_f_address_b,
				bram_f_data_out_b => mult_z2_bram_f_data_out_b,
				bram_g_address_a  => mult_z2_bram_g_address_a,
				bram_g_data_out_a => mult_z2_bram_g_data_out_a,
				bram_g_address_b  => mult_z2_bram_g_address_b,
				bram_g_data_out_b => mult_z2_bram_g_data_out_b
			);

	end generate gen_schoolbook_mult;

	block_ram_result : entity work.block_ram
		generic map(
			ADDRESS_WIDTH => bram_address_result_width,
			DATA_WIDTH    => q_num_bits
		)
		port map(
			clock      => clock,
			address_a  => bram_result_address_a,
			write_a    => bram_result_write_a,
			data_in_a  => bram_result_data_in_a,
			data_out_a => bram_result_data_out_a,
			address_b  => bram_result_address_b,
			write_b    => bram_result_write_b,
			data_in_b  => bram_result_data_in_b,
			data_out_b => bram_result_data_out_b
		);

end architecture RTL;

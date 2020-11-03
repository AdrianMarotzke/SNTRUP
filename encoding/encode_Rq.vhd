library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.constants.all;
use work.data_type.all;

-- Calculates the rq encoding according to the NTRU paper.
-- This compresses the polynomails by combining adjacent elements to a single integer
entity encode_Rq is
	port(
		clock        : in  std_logic;
		reset        : in  std_logic;
		input        : in  std_logic_vector(q_num_bits - 1 downto 0);
		input_valid  : in  std_logic;
		m_input      : in  std_logic_vector(15 downto 0);
		input_ack    : out std_logic;
		output       : out std_logic_vector(7 downto 0);
		output_valid : out std_logic;
		done         : out std_logic
	);
end entity encode_Rq;

architecture RTL of encode_Rq is

	type state_type is (idle, Ri_state, Ri1_state, calc_loop, output_state, next_loop, --
	                    next_recursion, Ri_state_d, Ri1_state_d, Ri1_state_d_wait, --
	                    final_output_state, done_state
	                   );
	signal state_encode : state_type;

	signal i : integer range 0 to p - 1;

	constant max_depth       : integer := p_num_bits;
	constant p_num_bits_half : integer := p_num_bits - 1;

	signal depth_counter : integer range 0 to max_depth - 1;

	signal reg_Ri  : unsigned(15 downto 0);
	signal reg_Ri1 : unsigned(15 downto 0);

	signal reg_r : unsigned(31 downto 0);
	signal reg_m : unsigned(31 downto 0);

	signal bram_r_address_a  : std_logic_vector(p_num_bits_half - 1 downto 0);
	signal bram_r_write_a    : std_logic;
	signal bram_r_data_in_a  : std_logic_vector(15 downto 0);
	signal bram_r_data_out_a : std_logic_vector(15 downto 0);

	signal bram_r_address_b  : std_logic_vector(p_num_bits_half - 1 downto 0);
	signal bram_r_data_out_b : std_logic_vector(15 downto 0);

	signal reg_length : integer range 0 to p;

	signal rounded_index_offset : integer range 0 to 21;
begin

	fsm_process : process(clock, reset) is
		variable var_m0 : unsigned(15 downto 0);
	begin
		if reset = '1' then
			state_encode   <= idle;
			bram_r_write_a <= '0';
			done           <= '0';
			output_valid   <= '0';
		elsif rising_edge(clock) then
			case state_encode is
				when idle =>
					state_encode   <= Ri_state;
					i              <= 0;
					depth_counter  <= 0;
					reg_length     <= p;
					done           <= '0';
					bram_r_write_a <= '0';
				when Ri_state =>

					if input_valid = '1' then
						state_encode <= Ri1_state;
						reg_Ri       <= resize(unsigned(input), 16);
					else
						state_encode <= Ri_state;
					end if;

					bram_r_write_a <= '0';
				when Ri1_state =>
					if input_valid = '1' then
						state_encode <= calc_loop;
						reg_Ri1      <= resize(unsigned(input), 16);
					else
						state_encode <= Ri1_state;
					end if;
				when calc_loop =>
					if depth_counter = 9 then
						state_encode <= final_output_state;
					else
						state_encode <= output_state;
					end if;

					if i >= reg_length - 2 then
						reg_m <= to_unsigned(M_array_squared(depth_counter * 2 + rounded_index_offset + 1), 32);
					else
						reg_m <= to_unsigned(M_array_squared(depth_counter * 2 + rounded_index_offset), 32);
					end if;

					var_m0 := to_unsigned(M_array(depth_counter + rounded_index_offset), 16);

					reg_r <= reg_Ri + reg_Ri1 * var_m0;
				when output_state =>
					if reg_m <= 16384 then
						state_encode <= next_loop;
						output_valid <= '0';

						bram_r_address_b <= std_logic_vector(to_unsigned(reg_length - 1, p_num_bits_half));
					else
						state_encode <= output_state;
						output       <= std_logic_vector(reg_r(7 downto 0));
						output_valid <= '1';
						reg_r        <= shift_right(reg_r, 8);
						reg_m        <= shift_right(reg_m + 255, 8);
					end if;
				when next_loop =>
					if i + 2 < reg_length - 1 then
						if depth_counter = 0 then
							state_encode <= Ri_state;
						else
							state_encode <= Ri_state_d;
						end if;
					else
						state_encode <= next_recursion;
					end if;

					bram_r_address_a <= std_logic_vector(to_unsigned(i / 2, p_num_bits_half));
					bram_r_write_a   <= '1';
					bram_r_data_in_a <= std_logic_vector(reg_r(15 downto 0));

					i <= i + 2;
				when next_recursion =>
					state_encode <= Ri_state_d;

					if i = reg_length - 1 then
						bram_r_address_a <= std_logic_vector(to_unsigned(i / 2, p_num_bits_half));
						bram_r_write_a   <= '1';

						if depth_counter = 0 then
							bram_r_data_in_a <= std_logic_vector(resize(unsigned(input), 16));
						else
							bram_r_data_in_a <= bram_r_data_out_b;
						end if;

					end if;

					depth_counter <= depth_counter + 1;
					i             <= 0;
					reg_length    <= (reg_length + 1) / 2;
				when Ri_state_d =>
					state_encode     <= Ri1_state_d;
					bram_r_address_a <= std_logic_vector(to_unsigned(i, p_num_bits_half));
					bram_r_address_b <= std_logic_vector(to_unsigned(i + 1, p_num_bits_half));
					bram_r_write_a   <= '0';
				when Ri1_state_d =>
					state_encode <= Ri1_state_d_wait;
				when Ri1_state_d_wait =>
					state_encode <= calc_loop;
					reg_Ri       <= unsigned(bram_r_data_out_a);
					reg_Ri1      <= unsigned(bram_r_data_out_b);
				when final_output_state =>
					if reg_m <= 1 then
						state_encode <= done_state;
						output_valid <= '0';
					else
						state_encode <= final_output_state;
						output       <= std_logic_vector(reg_r(7 downto 0));
						output_valid <= '1';
						reg_r        <= shift_right(reg_r, 8);
						reg_m        <= shift_right(reg_m + 255, 8);
					end if;
				when done_state =>
					state_encode <= idle;
					done         <= '1';
			end case;
		end if;
	end process fsm_process;

	rounded_index_offset <= 0 when unsigned(m_input) = to_unsigned(q, 16) else 21;

	block_ram_inst_r : entity work.block_ram
		generic map(
			ADDRESS_WIDTH => p_num_bits_half,
			DATA_WIDTH    => 16
		)
		port map(
			clock      => clock,
			address_a  => bram_r_address_a,
			write_a    => bram_r_write_a,
			data_in_a  => bram_r_data_in_a,
			data_out_a => bram_r_data_out_a,
			address_b  => bram_r_address_b,
			write_b    => '0',
			data_in_b  => (others => '0'),
			data_out_b => bram_r_data_out_b
		);

	input_ack <= '1' when (state_encode = Ri_state OR state_encode = Ri1_state) and input_valid = '1'
	             else '1' when state_encode = next_recursion and i = reg_length - 1 and depth_counter = 0
	             else '0';
end architecture RTL;

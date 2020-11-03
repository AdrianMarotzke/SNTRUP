library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.constants.all;

-- Calculates the reciprocal of the input in Zq 
entity modq_reciprocal is
	port(
		clock  : in  std_logic;
		reset  : in  std_logic;
		start  : in  std_logic;
		input  : in  std_logic_vector(q_num_bits - 1 downto 0);
		ready  : out std_logic;
		done   : out std_logic;
		output : out std_logic_vector(q_num_bits - 1 downto 0)
	);
end entity modq_reciprocal;

architecture RTL of modq_reciprocal is
	signal input_freeze  : signed(q_num_bits * 2 - 1 downto 0);
	signal output_freeze : signed(q_num_bits - 1 downto 0);

	type state_type is (idle_state, start_state, running, done_state, done_set_ready);
	signal state : state_type := idle_state;

	signal a1_reg : signed(q_num_bits - 1 downto 0);

	signal counter : integer range 0 to 2;

	function calc_square_or_multiply(q_num : integer)
	return std_logic_vector is
		variable q_run  : integer                              := q_num - 2;
		variable square : std_logic_vector(q_num - 2 downto 0) := (others => '0');
		variable i      : integer                              := q_num - 2;
	begin
		while q_run /= 0 loop
			if q_run mod 2 = 0 then
				q_run     := q_run / 2;
				i         := i / 2;
				square(i) := '1';
			else
				q_run     := q_run - 1;
				i         := i - 1;
				square(i) := '0';
			end if;
		end loop;

		return square;
	end function calc_square_or_multiply;

	constant square_or_multiply : std_logic_vector(q - 2 downto 0) := calc_square_or_multiply(q);

	procedure calc(signal counter          : inout integer;
	               signal input_a, input_b : in signed;
	               variable i              : inout integer;
	               signal input_freeze     : out signed
	              ) is

	begin
		if counter = 0 then
			counter <= counter + 1;
		else
			if counter = 2 then
				-- This is ok side channel wise,  as the sequence is fixed beforehand, and not secret dependant
				if square_or_multiply(i) = '1' then
					i := i * 2;
				else
					i := i + 1;
				end if;
				input_freeze <= input_a * input_b;
				counter      <= 0;
			else
				counter <= counter + 1;
			end if;

		end if;
	end procedure calc;

begin
	modq_freeze_inst : entity work.modq_freeze(RTL)
		port map(
			clock  => clock,
			reset  => reset,
			input  => input_freeze,
			output => output_freeze
		);

	fsm_process : process(clock, reset) is
		variable i : integer range 0 to q := 0;

	begin
		if reset = '1' then
			state        <= idle_state;
			--i     := 0;
			done         <= '0';
			input_freeze <= (others => '0');
			ready        <= '0';
		elsif rising_edge(clock) then
			case state is
				when idle_state =>
					if start = '1' then
						state <= start_state;
					end if;
					a1_reg  <= signed(input);
					i       := 1;
					counter <= 0;
					ready   <= '1';
				when start_state =>
					input_freeze <= a1_reg * a1_reg;
					done         <= '0';
					ready        <= '0';
					if counter = 0 then
						counter <= counter + 1;
					else
						if counter = 2 then
							state <= running;

							input_freeze <= a1_reg * a1_reg;
							counter      <= 0;
							i            := 2;
						else
							counter <= counter + 1;
						end if;
					end if;
				when running =>
					if i = q - 2 then
						state <= done_state;
					else
						-- This is ok side channel wise,  as the sequence is fixed beforehand, and not secret dependant
						if square_or_multiply(i) = '1' then
							calc(counter, output_freeze, output_freeze, i, input_freeze);
						else
							calc(counter, output_freeze, a1_reg, i, input_freeze);
						end if;

					end if;
				when done_state =>
					state <= done_set_ready;
					done  <= '1';
				when done_set_ready =>
					state <= idle_state;
					ready <= '1';
					done  <= '0';
			end case;
		end if;
	end process fsm_process;

	output <= std_logic_vector(output_freeze);

end architecture RTL;

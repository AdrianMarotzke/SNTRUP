library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

-- Constant time with regards to data sorting algorithm. Data is stored in a dual port RAM
entity sort_bram is
	generic(
		WIDTH              : natural := 32;
		ADDRESS_WIDTH      : natural := 5;
		NUMBER_OF_ELEMENTS : natural := 40
	);
	port(
		clock               : in  std_logic;
		reset               : in  std_logic;
		start               : in  std_logic;
		done                : out std_logic;
		bram_address_a      : out std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
		bram_write_a_enable : out std_logic;
		bram_data_in_a      : out std_logic_vector(WIDTH - 1 downto 0);
		bram_data_out_a     : in  std_logic_vector(WIDTH - 1 downto 0);
		bram_address_b      : out std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
		bram_write_b_enable : out std_logic;
		bram_data_in_b      : out std_logic_vector(WIDTH - 1 downto 0);
		bram_data_out_b     : in  std_logic_vector(WIDTH - 1 downto 0)
	);
end entity sort_bram;

architecture RTL of sort_bram is
	-- state variable to track main fsm, as well as wehter bram is currently being read or written
	type state_type is (reset_state, init, read, write, final, done_state);
	signal state_sort : state_type := reset_state;

	-- State variable to track in which inner loop the algorithm currently is
	type loop_state_type is (loop_p_i, loop_p_q_i);
	signal loop_state : loop_state_type;

	signal a   : unsigned(WIDTH - 1 downto 0);
	signal b   : unsigned(WIDTH - 1 downto 0);
	signal min : unsigned(WIDTH - 1 downto 0);
	signal max : unsigned(WIDTH - 1 downto 0);

	function calc_top(top_in : integer)
	return integer is
		variable top : integer;

	begin
		top := top_in;
		while top < NUMBER_OF_ELEMENTS - top loop
			top := top + top;
		end loop;

		return top;
	end function calc_top;

	constant TOP : integer := calc_top(1); --integer(ceil((real(NUMBER_OF_ELEMENTS) / real(2))));

	signal comparator_enable : std_logic;

	signal bram_write_fsm : std_logic;

	signal skip_s : std_logic;          -- signasl for simulator wave diagram

	-- Procedure to calculate the current state, ram addresses and indicies in the for loops
	-- The folowing sorting loop is used:
	-- for (p = top;p > 0;p >>= 1) {
	--    for (i = 0;i < n - p;++i)
	--      if (!(i & p))
	--        minmax(x + i,x + i + p);
	--    for (q = top;q > p;q >>= 1)
	--      for (i = 0;i < n - q;++i)
	--        if (!(i & p))
	--          minmax(x + i + p,x + i + q);
	--  }
	procedure calc_loop_states(variable p_v, q_v, i_v                : inout integer;
	                           signal loop_state                     : inout loop_state_type;
	                           signal bram_address_a, bram_address_b : out std_logic_vector;
	                           variable skip                         : inout std_ulogic
	                          ) is

	begin
		p_v := p_v;                     -- To remove warning in vivado
		if loop_state = loop_p_i then
			bram_address_a <= std_logic_vector(to_unsigned(i_v, ADDRESS_WIDTH));
			bram_address_b <= std_logic_vector(to_unsigned(i_v + p_v, ADDRESS_WIDTH));

			if (to_unsigned(i_v, 16) AND to_unsigned(p_v, 16)) = 0 then
				skip := '0';
			else
				i_v := i_v + p_v;
				if i_v >= NUMBER_OF_ELEMENTS - p_v then
					skip           := '1';
				end if;
				bram_address_a <= std_logic_vector(to_unsigned(i_v, ADDRESS_WIDTH));
				bram_address_b <= std_logic_vector(to_unsigned(i_v + p_v, ADDRESS_WIDTH));
			end if;
			i_v := i_v + 1;

			if i_v >= NUMBER_OF_ELEMENTS - p_v then
				i_v := 0;
				q_v := TOP;

				if q_v <= p_v then
					loop_state <= loop_p_i;
					p_v        := to_integer(shift_right(to_unsigned(p_v, 32), 1));
				else
					loop_state <= loop_p_q_i;
				end if;

			else
				loop_state <= loop_p_i;

				if skip = '1' then
					skip := '0';
				end if;

			end if;
		else
			bram_address_a <= std_logic_vector(to_unsigned(i_v + p_v, ADDRESS_WIDTH));
			bram_address_b <= std_logic_vector(to_unsigned(i_v + q_v, ADDRESS_WIDTH));

			if (to_unsigned(i_v, 16) AND to_unsigned(p_v, 16)) = 0 then
				skip := '0';
			else
				i_v            := i_v + p_v;
				if i_v >= NUMBER_OF_ELEMENTS - q_v then
					skip           := '1';
				end if;
				bram_address_a <= std_logic_vector(to_unsigned(i_v + p_v, ADDRESS_WIDTH));
				bram_address_b <= std_logic_vector(to_unsigned(i_v + q_v, ADDRESS_WIDTH));
			end if;
			i_v  := i_v + 1;

			if i_v >= NUMBER_OF_ELEMENTS - q_v then
				q_v := to_integer(shift_right(to_unsigned(q_v, 32), 1));

				if q_v > p_v then
					i_v := 0;

					loop_state <= loop_p_q_i;
				else
					p_v := to_integer(shift_right(to_unsigned(p_v, 32), 1));
					i_v := 0;

					loop_state <= loop_p_i;
				end if;
			end if;
		end if;
	end procedure calc_loop_states;

	signal p_v_s : integer range 0 to TOP + 1                := TOP;
	signal q_v_s : integer range 0 to TOP + 1                := TOP;
	signal i_v_s : integer range 0 to NUMBER_OF_ELEMENTS + 1 := 0;
begin

	process(clock, reset) is
		variable p_v  : integer range 0 to TOP + 1                := TOP;
		variable q_v  : integer range 0 to TOP + 1                := TOP;
		variable i_v  : integer range 0 to NUMBER_OF_ELEMENTS + 1 := 0;
		variable skip : std_logic;

	begin
		if reset = '1' then
			state_sort     <= reset_state;
			bram_write_fsm <= '0';

			bram_address_a <= (others => '0');
			bram_address_b <= (others => '0');
			loop_state     <= loop_p_i;
			done           <= '0';

			p_v := TOP;
			q_v := TOP;
			i_v := 0;
		elsif rising_edge(clock) then
			case state_sort is
				when reset_state =>
					state_sort <= init;
					loop_state <= loop_p_i;
				when init =>
					p_v            := TOP;
					q_v            := TOP;
					i_v            := 0;
					done           <= '0';
					bram_write_fsm <= '0';

					if start = '1' then
						state_sort <= read;
						calc_loop_states(p_v, q_v, i_v, loop_state, bram_address_a, bram_address_b, skip);
					else
						state_sort <= init;
					end if;
				when read =>
					state_sort     <= write;
					bram_write_fsm <= '1';
				when write =>

					bram_write_fsm <= '0';
					calc_loop_states(p_v, q_v, i_v, loop_state, bram_address_a, bram_address_b, skip);

					if p_v > 0 then
						if skip = '0' then
							state_sort <= read;
						else
							state_sort <= write;
						end if;

					else
						state_sort <= final;

					end if;
				when final =>
					state_sort     <= done_state;
					done           <= '1';
					bram_write_fsm <= '1';
				when done_state =>
					done           <= '0';
					bram_write_fsm <= '0';
					state_sort     <= init;
			end case;
			skip_s <= skip;
			p_v_s  <= p_v;
			i_v_s  <= i_v;
			q_v_s  <= q_v;
		end if;
	end process;

	-- Comparator to find max of the 2 elements recieved from the ram
	comparator_inst : entity work.comparator
		generic map(
			WIDTH => WIDTH
		)
		port map(
			a   => a,
			b   => b,
			min => min,
			max => max
		);

	a <= unsigned(bram_data_out_a);
	b <= unsigned(bram_data_out_b);

	-- Writer min useing ram port a, max useing ram port b
	bram_data_in_a <= std_logic_vector(min);
	bram_data_in_b <= std_logic_vector(max);

	comparator_enable <= '1';

	bram_write_a_enable <= bram_write_fsm and comparator_enable;
	bram_write_b_enable <= bram_write_fsm and comparator_enable;

end architecture RTL;

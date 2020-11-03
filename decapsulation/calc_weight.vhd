library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.constants.all;
use work.data_type.all;

-- Calcualtes if the weight of the a small polynomails equals w. If weight is equal to w, the mask_output is all zeros.
-- Otherswise, mask output is all ones
entity calc_weight is
	port(
		clock             : in  std_logic;
		reset             : in  std_logic;
		start             : in  std_logic;
		input             : in  std_logic_vector(1 downto 0);
		input_valid       : in  std_logic;
		mask_output       : out std_logic_vector(q_num_bits - 1 downto 0);
		mask_output_valid : out std_logic
	);
end entity calc_weight;

architecture RTL of calc_weight is

	type state_type is (idle, run, mask_weight, done_state);
	signal state_calc_weight : state_type;

	signal weight  : integer range 0 to p;-- Important: this must not overflow, so set range 0 to p
	signal counter : integer range 0 to p;

	signal signed_mask : signed(q_num_bits - 1 downto 0);

begin
	fsm_process : process(clock, reset) is
	begin
		if reset = '1' then
			state_calc_weight <= idle;
			mask_output_valid <= '0';
		elsif rising_edge(clock) then
			case state_calc_weight is
				when idle =>
					if start = '1' then
						state_calc_weight <= run;
					end if;
					weight            <= 0;
					counter           <= 0;
					mask_output_valid <= '0';
				when run =>
					if input_valid = '1' then
						counter <= counter + 1;
						weight  <= weight + to_integer(signed((input and "01")));
					end if;

					if counter = p - 1 then
						state_calc_weight <= mask_weight;
					end if;
				when mask_weight =>
					signed_mask       <= non_zero_mask(to_signed(weight - 2 * t, q_num_bits))(q_num_bits - 1 downto 0);
					state_calc_weight <= done_state;
				when done_state =>
					state_calc_weight <= idle;
					mask_output_valid <= '1';
					mask_output       <= std_logic_vector(signed_mask);
			end case;
		end if;
	end process fsm_process;

end architecture RTL;

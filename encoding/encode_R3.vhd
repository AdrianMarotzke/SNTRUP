library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.constants.all;

-- Calculates the zq encoding according to the NTRU paper.
-- This compresses 4 2-bit small elments into a single 8 byte word
entity encode_R3 is
	port(
		clock        : in  std_logic;
		reset        : in  std_logic;
		input        : in  std_logic_vector(1 downto 0);
		input_valid  : in  std_logic;
		output       : out std_logic_vector(7 downto 0);
		output_valid : out std_logic;
		done         : out std_logic
	);
end entity encode_R3;

architecture RTL2 of encode_R3 is

	signal counter : integer range 0 to p / 4;

	signal shift_reg : std_logic_vector(7 downto 0);

	signal input_plus_one : std_logic_vector(1 downto 0);

	type type_state is (first, second, third, fourth, final);
	signal state : type_state;
begin
	fsm_process : process(clock, reset) is
	begin
		if reset = '1' then
			state        <= first;
			counter      <= 0;
			output_valid <= '0';
			done         <= '0';
		elsif rising_edge(clock) then
			case state is
				when first =>
					if input_valid = '1' then
						state     <= second;
						shift_reg <= input_plus_one & shift_reg(7 downto 2);
					end if;
					output_valid <= '0';
					done         <= '0';
				when second =>
					if input_valid = '1' then
						state     <= third;
						shift_reg <= input_plus_one & shift_reg(7 downto 2);
					end if;
				when third =>
					if input_valid = '1' then
						state     <= fourth;
						shift_reg <= input_plus_one & shift_reg(7 downto 2);
					end if;
				when fourth =>
					if input_valid = '1' then
						counter <= counter + 1;
						if counter + 1 = p / 4 then
							state <= final;
						else
							state <= first;
						end if;

						shift_reg <= input_plus_one & shift_reg(7 downto 2);

						output_valid <= '1';
					end if;
				when final =>
					state        <= first;
					shift_reg    <= "000000" & input_plus_one;
					output_valid <= '1';
					done         <= '1';
					counter      <= 0;
			end case;
		end if;
	end process fsm_process;

	output         <= shift_reg;
	input_plus_one <= std_logic_vector(signed(input) + 1);
end architecture RTL2;

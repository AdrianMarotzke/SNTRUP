library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.constants.all;

-- Decodes the bytes wise encoded small elements into 2 bit small elements
-- input_ack is asserted whenever old byte is decoded, and new byte is needed
entity decode_R3 is
	port(
		clock        : in  std_logic;
		reset        : in  std_logic;
		input        : in  std_logic_vector(7 downto 0);
		input_valid  : in  std_logic;
		input_ack    : out std_logic;
		output       : out std_logic_vector(1 downto 0);
		output_valid : out std_logic;
		done         : out std_logic
	);
end entity decode_R3;

architecture RTL2 of decode_R3 is

	signal counter : integer range 0 to p / 4;

	signal shift_reg : std_logic_vector(7 downto 0);

	type type_state is (first, second, third, fourth, final, done_state);
	signal state : type_state;
begin
	fsm_process : process(clock, reset) is
	begin
		if reset = '1' then
			state        <= first;
			counter      <= 0;
			output_valid <= '0';
			done         <= '0';
			input_ack    <= '0';
		elsif rising_edge(clock) then
			case state is
				when first =>
					output_valid <= '0';
					input_ack    <= '0';
					if input_valid = '1' then
						state        <= second;
						shift_reg    <= input;
						input_ack    <= '1';
						output_valid <= '1';
					end if;
					done         <= '0';
				when second =>
					input_ack <= '0';
					state     <= third;
					shift_reg <= "00" & shift_reg(7 downto 2);
				when third =>
					state     <= fourth;
					shift_reg <= "00" & shift_reg(7 downto 2);
				when fourth =>
					counter <= counter + 1;
					if counter + 1 = p / 4 then
						state <= final;
					else
						state <= first;
					end if;

					shift_reg <= "00" & shift_reg(7 downto 2);
				when final =>
					state        <= done_state;
					shift_reg    <= input;
					input_ack    <= '1';
					output_valid <= '1';
					done         <= '1';
					counter      <= 0;
				when done_state => 
					state        <= first;
					output_valid <= '0';
					input_ack    <= '0';
					done         <= '0';
			end case;
		end if;
	end process fsm_process;

	output <= std_logic_vector(signed(shift_reg(1 downto 0)) - 1);
end architecture RTL2;

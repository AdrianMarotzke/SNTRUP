library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Generic simple dual port, single clock distrubuted RAM
entity SDP_dist_RAM is
	Generic(
		ADDRESS_WIDTH : integer := 8;
		DATA_WIDTH    : integer := 8
	);
	Port(clock      : in  STD_LOGIC;
	     address_a  : in  STD_LOGIC_VECTOR(ADDRESS_WIDTH - 1 downto 0);
	     data_out_a : out STD_LOGIC_VECTOR(DATA_WIDTH - 1 downto 0);
	     address_b  : in  STD_LOGIC_VECTOR(ADDRESS_WIDTH - 1 downto 0);
	     write_b    : in  STD_LOGIC;
	     data_in_b  : in  STD_LOGIC_VECTOR(DATA_WIDTH - 1 downto 0)
	    );
end entity SDP_dist_RAM;

architecture RTL of SDP_dist_RAM is
	type memory is array (0 to (2**ADDRESS_WIDTH) - 1) of STD_LOGIC_VECTOR(DATA_WIDTH - 1 downto 0);

	--signal RAM_s : memory;
	shared variable RAM : memory;

	attribute ram_style : string;
	attribute ram_style of RAM : variable is "distributed";
begin

	port_a : process(clock) is
	begin
		if rising_edge(clock) then
			data_out_a <= RAM(to_integer(unsigned(address_a)));

			-- Uncomment the follow line to be able to view RAM content in simulator
			-- RAM_s <= RAM;
		end if;
	end process port_a;

	port_b : process(clock) is
	begin
		if rising_edge(clock) then
			if (write_b = '1') then
				RAM(to_integer(unsigned(address_b))) := data_in_b;
			end if;
		end if;
	end process port_b;

	assert not ((address_a = address_b) and (write_b = '1') and rising_edge(clock)) report "Memory collision at " & integer'image(to_integer(unsigned(address_a))) severity warning;

end architecture RTL;

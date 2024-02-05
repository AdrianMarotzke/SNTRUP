library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Generic dual port, single clock block RAM
entity block_ram is
	Generic(
		ADDRESS_WIDTH : integer := 8;
		DATA_WIDTH    : integer := 8;
		DUAL_PORT     : boolean := TRUE
	);
	Port(clock      : in  STD_LOGIC;
	     address_a  : in  STD_LOGIC_VECTOR(ADDRESS_WIDTH - 1 downto 0);
	     write_a    : in  STD_LOGIC;
	     data_in_a  : in  STD_LOGIC_VECTOR(DATA_WIDTH - 1 downto 0);
	     data_out_a : out STD_LOGIC_VECTOR(DATA_WIDTH - 1 downto 0);
	     address_b  : in  STD_LOGIC_VECTOR(ADDRESS_WIDTH - 1 downto 0);
	     write_b    : in  STD_LOGIC;
	     data_in_b  : in  STD_LOGIC_VECTOR(DATA_WIDTH - 1 downto 0);
	     data_out_b : out STD_LOGIC_VECTOR(DATA_WIDTH - 1 downto 0)
	    );
end entity block_ram;

architecture RTL of block_ram is
	type memory is array (0 to (2**ADDRESS_WIDTH) - 1) of STD_LOGIC_VECTOR(DATA_WIDTH - 1 downto 0);

	--signal RAM_s : memory;
begin
	generate_label : if (DATA_WIDTH <= 8 and ADDRESS_WIDTH <= 8) or (DATA_WIDTH < 5) or (DATA_WIDTH * 2**ADDRESS_WIDTH <=3500) generate
		shared variable RAM : memory;

		attribute ram_style : string;
		attribute ram_style of RAM : variable is "distributed";
	begin
		port_a : process(clock) is
		begin
			if rising_edge(clock) then
				if (write_a = '1') then
					RAM(to_integer(unsigned(address_a))) := data_in_a;
				end if;
				data_out_a <= RAM(to_integer(unsigned(address_a)));

				-- Uncomment the follow line to be able to view RAM content in simulator
				-- RAM_s <= RAM;
			end if;
		end process port_a;

		generate_dual_port : if DUAL_PORT generate
			port_b : process(clock) is
			begin
				if rising_edge(clock) then
					if (write_b = '1') then
						RAM(to_integer(unsigned(address_b))) := data_in_b;
					end if;
					data_out_b <= RAM(to_integer(unsigned(address_b)));
				end if;
			end process port_b;
		end generate generate_dual_port;

	end generate generate_label;

	generate_label2 : if NOT ((DATA_WIDTH <= 8 and ADDRESS_WIDTH <= 8) or (DATA_WIDTH < 5) or (DATA_WIDTH * 2**ADDRESS_WIDTH <=3500)) generate
		shared variable RAM : memory;
	begin
		port_a : process(clock) is
		begin
			if rising_edge(clock) then
				if (write_a = '1') then
					RAM(to_integer(unsigned(address_a))) := data_in_a;
				end if;
				data_out_a <= RAM(to_integer(unsigned(address_a)));

				-- Uncomment the follow line to be able to view RAM content in simulator
				-- RAM_s <= RAM;
			end if;
		end process port_a;

		generate_dual_port : if DUAL_PORT generate
			port_b : process(clock) is
			begin
				if rising_edge(clock) then
					if (write_b = '1') then
						RAM(to_integer(unsigned(address_b))) := data_in_b;
					end if;
					data_out_b <= RAM(to_integer(unsigned(address_b)));
				end if;
			end process port_b;
		end generate generate_dual_port;
	end generate generate_label2;

	--assert not ((address_a = address_b) and (write_b = '1' or write_a = '1') and rising_edge(clock)) report "Memory collision at " & integer'image(to_integer(unsigned(address_a))) severity warning;

end architecture RTL;

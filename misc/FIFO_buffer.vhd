library ieee;
use ieee.std_logic_1164.all;

entity FIFO_buffer is
	generic(
		RAM_WIDTH : natural;
		RAM_DEPTH : natural
	);
	port(
		clock      : in  std_logic;
		reset      : in  std_logic;
		-- Write port
		wr_en      : in  std_logic;
		wr_data    : in  std_logic_vector(RAM_WIDTH - 1 downto 0);
		-- Read port
		rd_en      : in  std_logic;
		rd_valid   : out std_logic;
		rd_data    : out std_logic_vector(RAM_WIDTH - 1 downto 0);
		-- Flags
		empty      : out std_logic;
		empty_next : out std_logic;
		full       : out std_logic;
		full_next  : out std_logic
	);
end FIFO_buffer;

architecture rtl of FIFO_buffer is

	type ram_type is array (0 to RAM_DEPTH - 1) of std_logic_vector(wr_data'range);
	signal FIFO_ram : ram_type;

	attribute ram_style : string;
	attribute ram_style of FIFO_ram : signal is "distributed";
	
	subtype index_type is integer range ram_type'range;
	signal head : index_type;
	signal tail : index_type;

	signal empty_i      : std_logic;
	signal full_i       : std_logic;
	signal fill_count_i : integer range RAM_DEPTH - 1 downto 0;

	-- Increment and wrap
	procedure incr(signal index : inout index_type) is
	begin
		if index = index_type'high then
			index <= index_type'low;
		else
			index <= index + 1;
		end if;
	end procedure;

begin

	-- Copy internal signals to output
	empty <= empty_i;
	full  <= full_i;

	-- Set the flags
	empty_i    <= '1' when fill_count_i = 0 else '0';
	empty_next <= '1' when fill_count_i <= 1 else '0';
	full_i     <= '1' when fill_count_i >= RAM_DEPTH - 1 else '0';
	full_next  <= '1' when fill_count_i >= RAM_DEPTH - 2 else '0';

	-- Update the head pointer in write
	PROC_HEAD : process(clock)
	begin
		if rising_edge(clock) then
			if reset = '1' then
				head <= 0;
			else
				if wr_en = '1' and full_i = '0' then
					incr(head);
				end if;
			end if;
		end if;
	end process;

	-- Update the tail pointer on read and pulse valid
	PROC_TAIL : process(clock)
	begin
		if rising_edge(clock) then
			if reset = '1' then
				tail     <= 0;
				rd_valid <= '0';
			else
				rd_valid <= '0';

				if rd_en = '1' and empty_i = '0' then
					incr(tail);
					rd_valid <= '1';
				end if;

			end if;
		end if;
	end process;

	-- Write to and read from the RAM
	PROC_RAM : process(clock)
	begin
		if rising_edge(clock) then
			FIFO_ram(head) <= wr_data;
			rd_data        <= FIFO_ram(tail);
		end if;
	end process;

	-- Update the fill count
	PROC_COUNT : process(head, tail)
	begin
		if head < tail then
			fill_count_i <= head - tail + RAM_DEPTH;
		else
			fill_count_i <= head - tail;
		end if;
	end process;

end architecture;

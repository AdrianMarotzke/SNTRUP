--MIT License
--
--Original work Copyright (c) 2017 Danny Savory
--Modified work Copyright (c) 2020 Adrian Marotzke
--
--Permission is hereby granted, free of charge, to any person obtaining a copy
--of this software and associated documentation files (the "Software"), to deal
--in the Software without restriction, including without limitation the rights
--to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
--copies of the Software, and to permit persons to whom the Software is
--furnished to do so, subject to the following conditions:
--
--The above copyright notice and this permission notice shall be included in all
--copies or substantial portions of the Software.
--
--THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
--IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
--FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
--AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
--LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
--OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
--SOFTWARE.

-- ############################################################################
--  The official specifications of the SHA-256 algorithm can be found here:
--      http://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.180-4.pdf

-- ##################################################################
--     This SHA_512_CORE module reads in PADDED message blocks (from
--      an external source) and hashes the resulting message
-- ##################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.sha_512_pkg.all;

entity sha_512_core is
	generic(
		RESET_VALUE : std_logic := '0'  --reset enable value
	);
	port(
		clock              : in  std_logic;
		reset              : in  std_logic;
		data_ready         : in  std_logic; --the edge of this signal triggers the capturing of input data and hashing it.
		n_blocks           : in  natural range 0 to 16; --N, the number of (padded) message blocks
		msg_block_in       : in  std_logic_vector(0 to (16 * WORD_SIZE) - 1);
		read_msg_fifo_en   : out std_logic;
		read_msg_fifo_data : in  std_logic_vector(WORD_SIZE - 1 downto 0);
		ready              : out std_logic;
		finished           : out std_logic;
		data_out           : out std_logic_vector(WORD_SIZE - 1 downto 0) --SHA-512 results in a 512-bit hash value
	);
end entity;

architecture sha_512_core_ARCH of sha_512_core is
	signal HASH_ROUND_COUNTER    : natural; -- := 0;
	--signal MSG_BLOCK_COUNTER     : natural := 0;
	constant HASH_02_COUNT_LIMIT : natural := 80;
	signal HASH_02_COUNTER       : natural range 0 to HASH_02_COUNT_LIMIT;

	--Temporary words
	signal T1 : std_logic_vector(WORD_SIZE - 1 downto 0); -- := (others => '0');
	signal T2 : std_logic_vector(WORD_SIZE - 1 downto 0); -- := (others => '0');

	--signal T1a : std_logic_vector(WORD_SIZE - 1 downto 0); -- := (others => '0');
	--signal T2a : std_logic_vector(WORD_SIZE - 1 downto 0); -- := (others => '0');

	--Working variables, 8 64-bit words
	signal a : std_logic_vector(WORD_SIZE - 1 downto 0); -- := (others => '0');
	signal b : std_logic_vector(WORD_SIZE - 1 downto 0); -- := (others => '0');
	signal c : std_logic_vector(WORD_SIZE - 1 downto 0); -- := (others => '0');
	signal d : std_logic_vector(WORD_SIZE - 1 downto 0); -- := (others => '0');
	signal e : std_logic_vector(WORD_SIZE - 1 downto 0); -- := (others => '0');
	signal f : std_logic_vector(WORD_SIZE - 1 downto 0); -- := (others => '0');
	signal g : std_logic_vector(WORD_SIZE - 1 downto 0); -- := (others => '0');
	signal h : std_logic_vector(WORD_SIZE - 1 downto 0); -- := (others => '0');

	--Message blocks, the padded message should be a multiple of 512 bits,
	--	signal M : M_DATA;
	--
	--	constant K : K_DATA := (
	--		--address 0
	--		X"428a2f98d728ae22", X"7137449123ef65cd", X"b5c0fbcfec4d3b2f", X"e9b5dba58189dbbc",
	--		X"3956c25bf348b538", X"59f111f1b605d019", X"923f82a4af194f9b", X"ab1c5ed5da6d8118",
	--		X"d807aa98a3030242", X"12835b0145706fbe", X"243185be4ee4b28c", X"550c7dc3d5ffb4e2",
	--		X"72be5d74f27b896f", X"80deb1fe3b1696b1", X"9bdc06a725c71235", X"c19bf174cf692694",
	--		X"e49b69c19ef14ad2", X"efbe4786384f25e3", X"0fc19dc68b8cd5b5", X"240ca1cc77ac9c65",
	--		X"2de92c6f592b0275", X"4a7484aa6ea6e483", X"5cb0a9dcbd41fbd4", X"76f988da831153b5",
	--		X"983e5152ee66dfab", X"a831c66d2db43210", X"b00327c898fb213f", X"bf597fc7beef0ee4",
	--		X"c6e00bf33da88fc2", X"d5a79147930aa725", X"06ca6351e003826f", X"142929670a0e6e70",
	--		X"27b70a8546d22ffc", X"2e1b21385c26c926", X"4d2c6dfc5ac42aed", X"53380d139d95b3df",
	--		X"650a73548baf63de", X"766a0abb3c77b2a8", X"81c2c92e47edaee6", X"92722c851482353b",
	--		X"a2bfe8a14cf10364", X"a81a664bbc423001", X"c24b8b70d0f89791", X"c76c51a30654be30",
	--		X"d192e819d6ef5218", X"d69906245565a910", X"f40e35855771202a", X"106aa07032bbd1b8",
	--		X"19a4c116b8d2d0c8", X"1e376c085141ab53", X"2748774cdf8eeb99", X"34b0bcb5e19b48a8",
	--		X"391c0cb3c5c95a63", X"4ed8aa4ae3418acb", X"5b9cca4f7763e373", X"682e6ff3d6b2b8a3",
	--		X"748f82ee5defb2fc", X"78a5636f43172f60", X"84c87814a1f0ab72", X"8cc702081a6439ec",
	--		X"90befffa23631e28", X"a4506cebde82bde9", X"bef9a3f7b2c67915", X"c67178f2e372532b",
	--		X"ca273eceea26619c", X"d186b8c721c0c207", X"eada7dd6cde0eb1e", X"f57d4f7fee6ed178",
	--		X"06f067aa72176fba", X"0a637dc5a2c898a6", X"113f9804bef90dae", X"1b710b35131c471b",
	--		X"28db77f523047d84", X"32caab7b40c72493", X"3c9ebe0a15c9bebc", X"431d67c49c100d4c",
	--		X"4cc5d4becb3e42b6", X"597f299cfc657e2a", X"5fcb6fab3ad6faec", X"6c44198c4a475817"
	--	);

	--Hash values w/ initial hash values; 8 64-bit words
	--signal HV                  : H_DATA;
	constant HV_INITIAL_VALUES : H_DATA := (X"6a09e667f3bcc908", X"bb67ae8584caa73b",
	                                        X"3c6ef372fe94f82b", X"a54ff53a5f1d36f1",
	                                        X"510e527fade682d1", X"9b05688c2b3e6c1f",
	                                        X"1f83d9abfb41bd6b", X"5be0cd19137e2179");

	--intermediate Message block values; for use with a for-generate loop;
	--signal M_INT : M_DATA;

	--intermediate Message Schedule values; for use with a for-generate loop;
	--signal W_INT : K_DATA;
	--sliding window registers for intermediate Message Schedule values;
	type window_type is array (0 to 16) of std_logic_vector(WORD_SIZE - 1 downto 0);
	signal w_window : window_type;

	type SHA_512_HASH_CORE_STATE is (RESET_STATE, IDLE, READ_MSG_BLOCK, HASH_01_HV0, HASH_01_HV1, HASH_01_HV2, HASH_01_HV3, HASH_01_HV4,
	                                 HASH_01_HV5, HASH_01_HV6, HASH_01_HV7, HASH_01_END, HASH_02, HASH_02a, HASH_02b, HASH_03a, HASH_03_HV0, HASH_03_HV1,
	                                 HASH_03_HV2, HASH_03_HV3, HASH_03_HV4, HASH_03_HV5, HASH_03_HV6, HASH_03_HV7, DONE_a --, DONE_b, DONE_c, DONE_d
	                                );
	signal CURRENT_STATE, NEXT_STATE : SHA_512_HASH_CORE_STATE;
	--signal PREVIOUS_STATE            : SHA_512_HASH_CORE_STATE := READ_MSG_BLOCK;

	signal k_ROM_data_out : STD_LOGIC_VECTOR(WORD_SIZE - 1 downto 0);

	signal HV_ram_address_a  : STD_LOGIC_VECTOR(3 - 1 downto 0);
	signal HV_ram_data_out_a : STD_LOGIC_VECTOR(WORD_SIZE - 1 downto 0);
	signal HV_ram_address_b  : STD_LOGIC_VECTOR(3 - 1 downto 0);
	signal HV_ram_write_b    : STD_LOGIC;
	signal HV_ram_data_in_b  : STD_LOGIC_VECTOR(WORD_SIZE - 1 downto 0);

	signal n_blocks_reg : natural range 0 to 16;

	signal HV_addition_input  : STD_LOGIC_VECTOR(WORD_SIZE - 1 downto 0);
	signal HV_addition_output : STD_LOGIC_VECTOR(WORD_SIZE - 1 downto 0);

	signal HV_initial_input : STD_LOGIC_VECTOR(WORD_SIZE - 1 downto 0);
	
begin

	--current state logic
	process(clock, reset)
	begin
		if (reset = RESET_VALUE) then
			CURRENT_STATE <= RESET_STATE;
		elsif (clock'event and clock = '1') then
			CURRENT_STATE <= NEXT_STATE;
		end if;
	end process;

	--next state logic
	process(CURRENT_STATE, HASH_ROUND_COUNTER, HASH_02_COUNTER, reset, data_ready, n_blocks_reg)
	begin
		case CURRENT_STATE is
			when RESET_STATE =>
				if (reset = RESET_VALUE) then
					NEXT_STATE <= RESET_STATE;
				else
					NEXT_STATE <= IDLE;
				end if;
			when IDLE =>
				if (data_ready = '1') then
					NEXT_STATE <= READ_MSG_BLOCK;
				else
					NEXT_STATE <= IDLE;
				end if;
			when READ_MSG_BLOCK =>
				NEXT_STATE <= HASH_01_HV0;
			when HASH_01_HV0 =>
				NEXT_STATE <= HASH_01_HV1;
			when HASH_01_HV1 =>
				NEXT_STATE <= HASH_01_HV2;
			when HASH_01_HV2 =>
				NEXT_STATE <= HASH_01_HV3;
			when HASH_01_HV3 =>
				NEXT_STATE <= HASH_01_HV4;
			when HASH_01_HV4 =>
				NEXT_STATE <= HASH_01_HV5;
			when HASH_01_HV5 =>
				NEXT_STATE <= HASH_01_HV6;
			when HASH_01_HV6 =>
				NEXT_STATE <= HASH_01_HV7;
			when HASH_01_HV7 =>
				NEXT_STATE <= HASH_01_END;
			when HASH_01_END =>
				NEXT_STATE <= HASH_02;
			when HASH_02 =>
				if (HASH_02_COUNTER = HASH_02_COUNT_LIMIT) then
					NEXT_STATE <= HASH_03a;
				else
					NEXT_STATE <= HASH_02a;
				end if;
			when HASH_02a =>
				NEXT_STATE <= HASH_02b;
			when HASH_02b =>
				NEXT_STATE <= HASH_02;
			when HASH_03a =>
				NEXT_STATE <= HASH_03_HV0;
			when HASH_03_HV0 =>
				NEXT_STATE <= HASH_03_HV1;
			when HASH_03_HV1 =>
				NEXT_STATE <= HASH_03_HV2;
			when HASH_03_HV2 =>
				NEXT_STATE <= HASH_03_HV3;
			when HASH_03_HV3 =>
				NEXT_STATE <= HASH_03_HV4;
			when HASH_03_HV4 =>
				NEXT_STATE <= HASH_03_HV5;
			when HASH_03_HV5 =>
				NEXT_STATE <= HASH_03_HV6;
			when HASH_03_HV6 =>
				NEXT_STATE <= HASH_03_HV7;
			when HASH_03_HV7 =>
				if (HASH_ROUND_COUNTER = n_blocks_reg - 1) then
					NEXT_STATE <= DONE_a;
				else
					NEXT_STATE <= IDLE;
				end if;
			when DONE_a =>
				NEXT_STATE <= IDLE;

		end case;
	end process;

	--hash logic
	process(clock, reset)
		variable w_new : std_logic_vector(63 downto 0);

	begin
		if (reset = RESET_VALUE) then
			--HASH_ROUND_COUNTER <= 0;
			--MSG_BLOCK_COUNTER  <= 0;
			ready <= '0';
		elsif (clock'event and clock = '1') then
			a                  <= a;
			b                  <= b;
			c                  <= c;
			d                  <= d;
			e                  <= e;
			f                  <= f;
			g                  <= g;
			h                  <= h;
			T1                 <= T1;
			T2                 <= T2;
			--W                  <= W;
			--M                  <= M;
			--HV                 <= HV;
			HASH_02_COUNTER    <= HASH_02_COUNTER;
			HASH_ROUND_COUNTER <= HASH_ROUND_COUNTER;
			HV_ram_write_b     <= '0';
			case CURRENT_STATE is
				when RESET_STATE =>

				when IDLE =>            --the IDLE stage is a stall stage, perhaps waiting for new message block to arrive.
					ready            <= '1';
					read_msg_fifo_en <= '0';
					HASH_02_COUNTER  <= 0;
				when READ_MSG_BLOCK =>
					ready            <= '0';
					n_blocks_reg     <= n_blocks;
					HV_ram_address_a <= "000";
				when HASH_01_HV0 =>
					HV_ram_address_a <= "001";
				when HASH_01_HV1 =>
					HV_ram_address_a <= "010";
					if (HASH_ROUND_COUNTER = 0) then
						a                <= HV_INITIAL_VALUES(0);
						HV_ram_address_b <= "000";
						HV_ram_write_b   <= '1';
						HV_ram_data_in_b <= HV_INITIAL_VALUES(0);
					else
						a <= HV_ram_data_out_a;
					end if;
				when HASH_01_HV2 =>
					HV_ram_address_a <= "011";
					if (HASH_ROUND_COUNTER = 0) then
						b                <= HV_INITIAL_VALUES(1);
						HV_ram_address_b <= "001";
						HV_ram_write_b   <= '1';
						HV_ram_data_in_b <= HV_INITIAL_VALUES(1);
					else
						b <= HV_ram_data_out_a;
					end if;
				when HASH_01_HV3 =>
					HV_ram_address_a <= "100";
					if (HASH_ROUND_COUNTER = 0) then
						c                <= HV_INITIAL_VALUES(2);
						HV_ram_address_b <= "010";
						HV_ram_write_b   <= '1';
						HV_ram_data_in_b <= HV_INITIAL_VALUES(2);
					else
						c <= HV_ram_data_out_a;
					end if;
				when HASH_01_HV4 =>
					HV_ram_address_a <= "101";
					if (HASH_ROUND_COUNTER = 0) then
						d                <= HV_INITIAL_VALUES(3);
						HV_ram_address_b <= "011";
						HV_ram_write_b   <= '1';
						HV_ram_data_in_b <= HV_INITIAL_VALUES(3);
					else
						d <= HV_ram_data_out_a;
					end if;
				when HASH_01_HV5 =>
					HV_ram_address_a <= "110";
					if (HASH_ROUND_COUNTER = 0) then
						e                <= HV_INITIAL_VALUES(4);
						HV_ram_address_b <= "100";
						HV_ram_write_b   <= '1';
						HV_ram_data_in_b <= HV_INITIAL_VALUES(4);
					else
						e <= HV_ram_data_out_a;
					end if;
				when HASH_01_HV6 =>
					HV_ram_address_a <= "111";
					if (HASH_ROUND_COUNTER = 0) then
						f                <= HV_INITIAL_VALUES(5);
						HV_ram_address_b <= "101";
						HV_ram_write_b   <= '1';
						HV_ram_data_in_b <= HV_INITIAL_VALUES(5);
					else
						f <= HV_ram_data_out_a;
					end if;
				when HASH_01_HV7 =>
					if (HASH_ROUND_COUNTER = 0) then
						g                <= HV_INITIAL_VALUES(6);
						HV_ram_address_b <= "110";
						HV_ram_write_b   <= '1';
						HV_ram_data_in_b <= HV_INITIAL_VALUES(6);
					else
						g <= HV_ram_data_out_a;
					end if;
				when HASH_01_END =>
					if (HASH_ROUND_COUNTER = 0) then
						h                <= HV_INITIAL_VALUES(7);
						HV_ram_address_b <= "111";
						HV_ram_write_b   <= '1';
						HV_ram_data_in_b <= HV_INITIAL_VALUES(7);
					else
						h <= HV_ram_data_out_a;
					end if;
				when HASH_02 =>
					read_msg_fifo_en <= '0';
					if HASH_02_COUNTER < 16 then
						w_new            := read_msg_fifo_data;
						read_msg_fifo_en <= '1';
					else
						w_new := std_logic_vector(unsigned(SIGMA_LCASE_1(w_window(1))) + unsigned(w_window(6)) + unsigned(SIGMA_LCASE_0(w_window(14))) + unsigned(w_window(15)));
					end if;

					w_window(0) <= w_new;

					for i in 1 to 16 loop
						w_window(i) <= w_window(i - 1);
					end loop;

					if (HASH_02_COUNTER = HASH_02_COUNT_LIMIT) then
						HASH_02_COUNTER <= 0;
					end if;

					HV_ram_address_a <= "000";
				when HASH_02a =>
					read_msg_fifo_en <= '0';
					--you have to set T1 and T2 in a different state, due to how
					--VHDL sequential/process statements are evaluated.
					T1               <= std_logic_vector(unsigned(h) + unsigned(SIGMA_UCASE_1(e)) + unsigned(CH(e, f, g)) + unsigned(k_ROM_data_out) + unsigned(w_new));
					T2               <= std_logic_vector(unsigned(SIGMA_UCASE_0(a)) + unsigned(MAJ(a, b, c)));
				when HASH_02b =>
					h               <= g;
					g               <= f;
					f               <= e;
					e               <= std_logic_vector(unsigned(d) + unsigned(T1));
					d               <= c;
					c               <= b;
					b               <= a;
					a               <= std_logic_vector(unsigned(T1) + unsigned(T2));
					HASH_02_COUNTER <= HASH_02_COUNTER + 1; --increment counter
				when HASH_03a =>
					HV_ram_address_a <= "001";
				when HASH_03_HV0 =>
					HV_ram_address_a <= "010";
					HV_ram_address_b <= "000";
					HV_ram_write_b   <= '1';
					HV_ram_data_in_b <= HV_addition_output;
				when HASH_03_HV1 =>
					HV_ram_address_a <= "011";
					HV_ram_address_b <= "001";
					HV_ram_write_b   <= '1';
					HV_ram_data_in_b <= HV_addition_output;
				when HASH_03_HV2 =>
					HV_ram_address_a <= "100";
					HV_ram_address_b <= "010";
					HV_ram_write_b   <= '1';
					HV_ram_data_in_b <= HV_addition_output;
				when HASH_03_HV3 =>
					HV_ram_address_a <= "101";
					HV_ram_address_b <= "011";
					HV_ram_write_b   <= '1';
					HV_ram_data_in_b <= HV_addition_output;
				when HASH_03_HV4 =>
					HV_ram_address_a <= "110";
					HV_ram_address_b <= "100";
					HV_ram_write_b   <= '1';
					HV_ram_data_in_b <= HV_addition_output;
				when HASH_03_HV5 =>
					HV_ram_address_a <= "111";
					HV_ram_address_b <= "101";
					HV_ram_write_b   <= '1';
					HV_ram_data_in_b <= HV_addition_output;
				when HASH_03_HV6 =>
					HV_ram_address_b <= "110";
					HV_ram_write_b   <= '1';
					HV_ram_data_in_b <= HV_addition_output;
				when HASH_03_HV7 =>
					HV_ram_address_b   <= "111";
					HV_ram_write_b     <= '1';
					HV_ram_data_in_b <= HV_addition_output;
					HASH_ROUND_COUNTER <= HASH_ROUND_COUNTER + 1; --increment counter, read in next message block
				when DONE_a =>
					HASH_ROUND_COUNTER <= 0;
			end case;
		end if;
	end process;

	K_ROM_inst : entity work.K_ROM
		port map(
			clock    => clock,
			address  => HASH_02_COUNTER,
			data_out => k_ROM_data_out
		);

	HV_SDP_dist_RAM_inst : entity work.SDP_dist_RAM
		generic map(
			ADDRESS_WIDTH => 3,
			DATA_WIDTH    => 64
		)
		port map(
			clock      => clock,
			address_a  => HV_ram_address_a,
			data_out_a => HV_ram_data_out_a,
			address_b  => HV_ram_address_b,
			write_b    => HV_ram_write_b,
			data_in_b  => HV_ram_data_in_b
		);
	HV_addition_input <= a when CURRENT_STATE = HASH_03_HV0
	                     else b when CURRENT_STATE = HASH_03_HV1
	                     else c when CURRENT_STATE = HASH_03_HV2
	                     else d when CURRENT_STATE = HASH_03_HV3
	                     else e when CURRENT_STATE = HASH_03_HV4
	                     else f when CURRENT_STATE = HASH_03_HV5
	                     else g when CURRENT_STATE = HASH_03_HV6
	                     else h;

	HV_addition_output <= std_logic_vector(unsigned(HV_addition_input) + unsigned(HV_ram_data_out_a));
	
	                   --FINISHED signal asserts when hashing is done
	finished <= '1' when CURRENT_STATE = HASH_03_HV1 and HASH_ROUND_COUNTER = n_blocks_reg - 1 else '0';

	data_out <= HV_ram_data_in_b;
end architecture;


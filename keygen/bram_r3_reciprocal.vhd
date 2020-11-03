library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.constants.all;
use ieee.math_real.all;

-- contains of the memories for the reciprocal calculation of r3 polynomials
entity bram_r3_reciprocal is
	generic(
		bram_address_width : integer := integer(ceil(log2(real(p + 1))));
		bram_data_width    : integer := q_num_bits
	);
	port(
		clock             : in  std_logic;
		swap_mask_s       : in  std_logic;
		---
		bram_f_address_a  : in  std_logic_vector(bram_address_width - 1 downto 0);
		bram_g_address_a  : in  std_logic_vector(bram_address_width - 1 downto 0);
		bram_v_address_a  : in  std_logic_vector(bram_address_width - 1 downto 0);
		bram_r_address_a  : in  std_logic_vector(bram_address_width - 1 downto 0);
		bram_f_data_out_a : out std_logic_vector(bram_data_width - 1 downto 0);
		bram_g_data_out_a : out std_logic_vector(bram_data_width - 1 downto 0);
		bram_v_data_out_a : out std_logic_vector(bram_data_width - 1 downto 0);
		bram_r_data_out_a : out std_logic_vector(bram_data_width - 1 downto 0);
		---
		bram_f_data_in_b  : in  std_logic_vector(bram_data_width - 1 downto 0);
		bram_g_data_in_b  : in  std_logic_vector(bram_data_width - 1 downto 0);
		bram_v_data_in_b  : in  std_logic_vector(bram_data_width - 1 downto 0);
		bram_r_data_in_b  : in  std_logic_vector(bram_data_width - 1 downto 0);
		bram_f_write_b    : in  std_logic;
		bram_g_write_b    : in  std_logic;
		bram_v_write_b    : in  std_logic;
		bram_r_write_b    : in  std_logic;
		bram_f_address_b  : in  std_logic_vector(bram_address_width - 1 downto 0);
		bram_g_address_b  : in  std_logic_vector(bram_address_width - 1 downto 0);
		bram_v_address_b  : in  std_logic_vector(bram_address_width - 1 downto 0);
		bram_r_address_b  : in  std_logic_vector(bram_address_width - 1 downto 0)
	);
end entity bram_r3_reciprocal;

architecture RTL of bram_r3_reciprocal is

	signal bram_fg_one_address_a  : STD_LOGIC_VECTOR(bram_address_width - 1 downto 0);
	signal bram_fg_one_write_a    : STD_LOGIC;
	signal bram_fg_one_data_in_a  : STD_LOGIC_VECTOR(bram_data_width - 1 downto 0);
	signal bram_fg_one_data_out_a : STD_LOGIC_VECTOR(bram_data_width - 1 downto 0);
	signal bram_fg_one_address_b  : STD_LOGIC_VECTOR(bram_address_width - 1 downto 0);
	signal bram_fg_one_write_b    : STD_LOGIC;
	signal bram_fg_one_data_in_b  : STD_LOGIC_VECTOR(bram_data_width - 1 downto 0);
	signal bram_fg_one_data_out_b : STD_LOGIC_VECTOR(bram_data_width - 1 downto 0);

	signal bram_fg_two_address_a  : STD_LOGIC_VECTOR(bram_address_width - 1 downto 0);
	signal bram_fg_two_write_a    : STD_LOGIC;
	signal bram_fg_two_data_in_a  : STD_LOGIC_VECTOR(bram_data_width - 1 downto 0);
	signal bram_fg_two_data_out_a : STD_LOGIC_VECTOR(bram_data_width - 1 downto 0);
	signal bram_fg_two_address_b  : STD_LOGIC_VECTOR(bram_address_width - 1 downto 0);
	signal bram_fg_two_write_b    : STD_LOGIC;
	signal bram_fg_two_data_in_b  : STD_LOGIC_VECTOR(bram_data_width - 1 downto 0);
	signal bram_fg_two_data_out_b : STD_LOGIC_VECTOR(bram_data_width - 1 downto 0);

	signal bram_vr_one_address_a  : STD_LOGIC_VECTOR(bram_address_width - 1 downto 0);
	signal bram_vr_one_write_a    : STD_LOGIC;
	signal bram_vr_one_data_in_a  : STD_LOGIC_VECTOR(bram_data_width - 1 downto 0);
	signal bram_vr_one_data_out_a : STD_LOGIC_VECTOR(bram_data_width - 1 downto 0);
	signal bram_vr_one_address_b  : STD_LOGIC_VECTOR(bram_address_width - 1 downto 0);
	signal bram_vr_one_write_b    : STD_LOGIC;
	signal bram_vr_one_data_in_b  : STD_LOGIC_VECTOR(bram_data_width - 1 downto 0);
	signal bram_vr_one_data_out_b : STD_LOGIC_VECTOR(bram_data_width - 1 downto 0);

	signal bram_vr_two_address_a  : STD_LOGIC_VECTOR(bram_address_width - 1 downto 0);
	signal bram_vr_two_write_a    : STD_LOGIC;
	signal bram_vr_two_data_in_a  : STD_LOGIC_VECTOR(bram_data_width - 1 downto 0);
	signal bram_vr_two_data_out_a : STD_LOGIC_VECTOR(bram_data_width - 1 downto 0);
	signal bram_vr_two_address_b  : STD_LOGIC_VECTOR(bram_address_width - 1 downto 0);
	signal bram_vr_two_write_b    : STD_LOGIC;
	signal bram_vr_two_data_in_b  : STD_LOGIC_VECTOR(bram_data_width - 1 downto 0);
	signal bram_vr_two_data_out_b : STD_LOGIC_VECTOR(bram_data_width - 1 downto 0);

begin
	bram_fg_one_data_in_b <= bram_f_data_in_b when swap_mask_s = '0' else bram_g_data_in_b;
	bram_fg_two_data_in_b <= bram_g_data_in_b when swap_mask_s = '0' else bram_f_data_in_b;

	bram_fg_one_address_b <= bram_f_address_b when swap_mask_s = '0' else bram_g_address_b;
	bram_fg_two_address_b <= bram_g_address_b when swap_mask_s = '0' else bram_f_address_b;

	bram_fg_one_write_b <= bram_f_write_b when swap_mask_s = '0' else bram_g_write_b;
	bram_fg_two_write_b <= bram_g_write_b when swap_mask_s = '0' else bram_f_write_b;

	bram_vr_one_data_in_b <= bram_v_data_in_b when swap_mask_s = '0' else bram_r_data_in_b;
	bram_vr_two_data_in_b <= bram_r_data_in_b when swap_mask_s = '0' else bram_v_data_in_b;

	bram_vr_one_address_b <= bram_v_address_b when swap_mask_s = '0' else bram_r_address_b;
	bram_vr_two_address_b <= bram_r_address_b when swap_mask_s = '0' else bram_v_address_b;

	bram_vr_one_write_b <= bram_v_write_b when swap_mask_s = '0' else bram_r_write_b;
	bram_vr_two_write_b <= bram_r_write_b when swap_mask_s = '0' else bram_v_write_b;

	bram_fg_one_data_in_a <= (others => '0');
	bram_fg_two_data_in_a <= (others => '0');
	bram_vr_one_data_in_a <= (others => '0');
	bram_vr_two_data_in_a <= (others => '0');

	bram_fg_one_write_a <= '0';
	bram_fg_two_write_a <= '0';
	bram_vr_one_write_a <= '0';
	bram_vr_two_write_a <= '0';

	bram_fg_one_address_a <= bram_f_address_a when swap_mask_s = '0' else bram_g_address_a;
	bram_fg_two_address_a <= bram_g_address_a when swap_mask_s = '0' else bram_f_address_a;
	bram_vr_one_address_a <= bram_v_address_a when swap_mask_s = '0' else bram_r_address_a;
	bram_vr_two_address_a <= bram_r_address_a when swap_mask_s = '0' else bram_v_address_a;

	bram_f_data_out_a <= bram_fg_one_data_out_a when swap_mask_s = '0' else bram_fg_two_data_out_a;
	bram_g_data_out_a <= bram_fg_two_data_out_a when swap_mask_s = '0' else bram_fg_one_data_out_a;
	bram_v_data_out_a <= bram_vr_one_data_out_a when swap_mask_s = '0' else bram_vr_two_data_out_a;
	bram_r_data_out_a <= bram_vr_two_data_out_a when swap_mask_s = '0' else bram_vr_one_data_out_a;

	block_ram_inst_fg_one : entity work.SDP_dist_RAM
		generic map(
			ADDRESS_WIDTH => bram_address_width,
			DATA_WIDTH    => bram_data_width
		)
		port map(
			clock      => clock,
			address_a  => bram_fg_one_address_a,
			data_out_a => bram_fg_one_data_out_a,
			address_b  => bram_fg_one_address_b,
			write_b    => bram_fg_one_write_b,
			data_in_b  => bram_fg_one_data_in_b
		);

	block_ram_inst_fg_two : entity work.SDP_dist_RAM
		generic map(
			ADDRESS_WIDTH => bram_address_width,
			DATA_WIDTH    => bram_data_width
		)
		port map(
			clock      => clock,
			address_a  => bram_fg_two_address_a,
			data_out_a => bram_fg_two_data_out_a,
			address_b  => bram_fg_two_address_b,
			write_b    => bram_fg_two_write_b,
			data_in_b  => bram_fg_two_data_in_b
		);

	block_ram_inst_vr_one : entity work.SDP_dist_RAM
		generic map(
			ADDRESS_WIDTH => bram_address_width,
			DATA_WIDTH    => bram_data_width
		)
		port map(
			clock      => clock,
			address_a  => bram_vr_one_address_a,
			data_out_a => bram_vr_one_data_out_a,
			address_b  => bram_vr_one_address_b,
			write_b    => bram_vr_one_write_b,
			data_in_b  => bram_vr_one_data_in_b
		);

	block_ram_inst_vr_two : entity work.SDP_dist_RAM
		generic map(
			ADDRESS_WIDTH => bram_address_width,
			DATA_WIDTH    => bram_data_width
		)
		port map(
			clock      => clock,
			address_a  => bram_vr_two_address_a,
			data_out_a => bram_vr_two_data_out_a,
			address_b  => bram_vr_two_address_b,
			write_b    => bram_vr_two_write_b,
			data_in_b  => bram_vr_two_data_in_b
		);
end architecture RTL;

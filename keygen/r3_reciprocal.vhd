library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use ieee.math_real.all;

use work.constants.all;
use work.data_type.all;


-- Calculates the reciprocal of a polynomial in r3
entity r3_reciprocal is
	port(
		clock               : in  std_logic;
		reset               : in  std_logic;
		start               : in  std_logic;
		small_polynomial_in : in  std_logic_vector(1 downto 0);
		ready               : out std_logic;
		output_polynomial   : out std_logic_vector(1 downto 0);
		output_valid        : out std_logic;
		is_invertable       : out std_logic;
		done                : out std_logic
	);
end entity r3_reciprocal;

architecture RTL of r3_reciprocal is
	constant loop_limit : integer := 2 * p - 1;

	constant bram_address_width : integer := integer(ceil(log2(real(p + 1))));

	signal counter             : integer range 0 to loop_limit + 1 := 0;
	type state_type is (init_state, reset_ram, reset_ram_end, ready_state, running_state, swap_state_1, swap_state_2, swap_state_3, multiply_state_read, multiply_final_state_1, multiply_final_state_2, calc_reciprocal_init, calc_reciprocal_init_2, calc_reciprocal, output_data, done_state);
	signal state_r3_reciprocal : state_type;

	signal counter_vr : integer range 0 to p + 2;
	signal counter_fg : integer range 0 to p + 2;

	signal bram_f_write_b_reset : std_logic;
	signal bram_g_write_b_reset : std_logic;
	signal bram_v_write_b_reset : std_logic;
	signal bram_r_write_b_reset : std_logic;

	signal bram_f_data_in_b_reset : std_logic_vector(1 downto 0);
	signal bram_g_data_in_b_reset : std_logic_vector(1 downto 0);
	signal bram_v_data_in_b_reset : std_logic_vector(1 downto 0);
	signal bram_r_data_in_b_reset : std_logic_vector(1 downto 0);

	signal bram_f_address_b_reset : std_logic_vector(bram_address_width - 1 downto 0);
	signal bram_g_address_b_reset : std_logic_vector(bram_address_width - 1 downto 0);
	signal bram_v_address_b_reset : std_logic_vector(bram_address_width - 1 downto 0);
	signal bram_r_address_b_reset : std_logic_vector(bram_address_width - 1 downto 0);

	signal bram_f_address_a : std_logic_vector(bram_address_width - 1 downto 0);
	signal bram_g_address_a : std_logic_vector(bram_address_width - 1 downto 0);
	signal bram_v_address_a : std_logic_vector(bram_address_width - 1 downto 0);
	signal bram_r_address_a : std_logic_vector(bram_address_width - 1 downto 0);

	signal bram_f_data_out_a : std_logic_vector(1 downto 0);
	signal bram_g_data_out_a : std_logic_vector(1 downto 0);
	signal bram_v_data_out_a : std_logic_vector(1 downto 0);
	signal bram_r_data_out_a : std_logic_vector(1 downto 0);

	signal swap_mask_s : std_logic;

	signal f_zero : std_logic_vector(1 downto 0);
	signal g_zero : std_logic_vector(1 downto 0);

	signal fg_freeze : signed(1 downto 0);

	signal bram_f_data_in_b : std_logic_vector(1 downto 0);
	signal bram_g_data_in_b : std_logic_vector(1 downto 0);
	signal bram_v_data_in_b : std_logic_vector(1 downto 0);
	signal bram_r_data_in_b : std_logic_vector(1 downto 0);

	signal bram_f_write_b : std_logic;
	signal bram_g_write_b : std_logic;
	signal bram_v_write_b : std_logic;
	signal bram_r_write_b : std_logic;

	signal bram_f_address_b : std_logic_vector(bram_address_width - 1 downto 0);
	signal bram_g_address_b : std_logic_vector(bram_address_width - 1 downto 0);
	signal bram_v_address_b : std_logic_vector(bram_address_width - 1 downto 0);
	signal bram_r_address_b : std_logic_vector(bram_address_width - 1 downto 0);

	constant pipeline_length : integer := 1;

	type address_delay is array (pipeline_length downto 0) of std_logic_vector(bram_address_width - 1 downto 0);

	signal bram_g_address_b_delay : address_delay;
	signal bram_g_write_b_delay   : std_logic_vector(pipeline_length downto 0);

	signal vr_freeze : signed(1 downto 0);

	signal bram_r_address_b_delay : address_delay;
	signal bram_r_write_b_delay   : std_logic_vector(pipeline_length downto 0);

	-- Shift data in v RAM
	signal bram_shift_v_address_b : std_logic_vector(bram_address_width - 1 downto 0);
	signal bram_shift_v_data_in_b : std_logic_vector(1 downto 0);
	signal bram_shift_v_write_b   : std_logic;

	signal reciprocal_output : std_logic_vector(1 downto 0);

	signal output_freeze : signed(1 downto 0);

	signal output_valid_pipe : std_logic_vector(pipeline_length downto 0);

	signal v_g0_inter : signed(1 downto 0);
	signal r_f0_inter : signed(1 downto 0);

	signal f_g0_inter : signed(1 downto 0);
	signal g_f0_inter : signed(1 downto 0);

begin

	main : process(clock, reset) is
		variable delta : signed(15 downto 0);

		variable swap_mask : signed(15 downto 0);

	begin
		if reset = '1' then
			state_r3_reciprocal <= init_state;

			bram_g_address_b_delay(0) <= (others => '0');
			bram_g_write_b_delay(0)   <= '0';

			bram_r_address_b_delay(0) <= (others => '0');
			bram_r_write_b_delay(0)   <= '0';

			bram_f_write_b_reset <= '0';
			bram_g_write_b_reset <= '0';
			bram_v_write_b_reset <= '0';
			bram_r_write_b_reset <= '0';

			bram_f_data_in_b_reset <= (others => '0');
			bram_g_data_in_b_reset <= (others => '0');
			bram_v_data_in_b_reset <= (others => '0');
			bram_r_data_in_b_reset <= (others => '0');

			f_zero <= (others => '0');
			g_zero <= (others => '0');

			bram_shift_v_write_b    <= '0';
			bram_r_write_b_delay(0) <= '0';

			done          <= '0';
			is_invertable <= '0';

			output_valid_pipe(0) <= '0';
		elsif rising_edge(clock) then
			case state_r3_reciprocal is
				when init_state =>
					state_r3_reciprocal  <= ready_state;
					delta                := to_signed(1, 16);
					swap_mask            := (others => '0');
					counter              <= 0;
					counter_vr           <= 0;
					counter_fg           <= 0;
					output_valid_pipe(0) <= '0';
					ready                <= '0';
					swap_mask_s          <= '0';
					done                 <= '0';
					is_invertable        <= '0';
				when ready_state =>
					if start = '1' then
						state_r3_reciprocal <= reset_ram;
						ready               <= '0';
					else
						state_r3_reciprocal <= ready_state;
						ready               <= '1';
					end if;
					bram_f_write_b_reset <= '0';
					bram_g_write_b_reset <= '0';
					bram_v_write_b_reset <= '0';
					bram_r_write_b_reset <= '0';
				when reset_ram =>

					bram_f_address_b_reset <= std_logic_vector(to_unsigned(counter_fg, bram_address_width));
					bram_g_address_b_reset <= std_logic_vector(to_unsigned(p - 1 - counter_fg, bram_address_width));

					bram_v_address_b_reset <= std_logic_vector(to_unsigned(counter_vr, bram_address_width));
					bram_r_address_b_reset <= std_logic_vector(to_unsigned(counter_vr, bram_address_width));

					if counter_fg = 0 then
						bram_f_data_in_b_reset <= std_logic_vector(to_signed(1, 2));
					elsif counter_fg = p or counter_fg = p - 1 then
						bram_f_data_in_b_reset <= std_logic_vector(to_signed(-1, 2));
					else
						bram_f_data_in_b_reset <= (others => '0');
					end if;

					if counter_fg < p then
						bram_g_data_in_b_reset <= std_logic_vector(resize(signed(small_polynomial_in), 2));
					else
						bram_g_data_in_b_reset <= (others => '0');
						bram_g_address_b_reset <= std_logic_vector(to_unsigned(p, bram_address_width));
					end if;

					bram_v_data_in_b_reset <= (others => '0');

					if counter_vr = 0 then
						bram_r_data_in_b_reset <= std_logic_vector(to_signed(1, 2));
					else
						bram_r_data_in_b_reset <= (others => '0');

					end if;

					bram_f_write_b_reset <= '1';
					bram_g_write_b_reset <= '1';
					bram_v_write_b_reset <= '1';
					bram_r_write_b_reset <= '1';

					counter_fg <= counter_fg + 1;
					counter_vr <= counter_vr + 1;
					if counter_fg < p + 1 then
						state_r3_reciprocal <= reset_ram;

					else
						state_r3_reciprocal <= reset_ram_end;
					end if;
				when reset_ram_end =>
					state_r3_reciprocal     <= running_state;
					bram_g_address_b_reset  <= (others => '0');
					bram_f_address_b_reset  <= (others => '0');
					bram_g_write_b_delay(0) <= '0';
					bram_r_write_b_delay(0) <= '0';
					bram_shift_v_write_b    <= '0';
					bram_f_write_b_reset    <= '0';
					bram_g_write_b_reset    <= '0';
					bram_v_write_b_reset    <= '0';
					bram_r_write_b_reset    <= '0';
				when running_state =>
					if counter >= loop_limit then
						state_r3_reciprocal <= calc_reciprocal_init;
					else
						state_r3_reciprocal <= swap_state_1;
					end if;
					bram_g_address_b_reset <= (others => '0');
					bram_f_address_b_reset <= (others => '0');

					counter                 <= counter + 1;
					counter_fg              <= 1;
					counter_vr              <= 0;
					bram_g_write_b_delay(0) <= '0';
					bram_r_write_b_delay(0) <= '0';
					bram_shift_v_write_b    <= '0';
				when swap_state_1 =>
					state_r3_reciprocal <= swap_state_2;
				when swap_state_2 =>
					state_r3_reciprocal <= swap_state_3;
					swap_mask           := negative_mask(-delta) AND non_zero_mask(signed(bram_g_data_out_a));
					delta               := (delta XOR (swap_mask AND (delta XOR -delta))) + to_signed(1, 16);

					if swap_mask(0) = '1' then
						swap_mask_s <= not swap_mask_s;
					else
						swap_mask_s <= swap_mask_s;
					end if;
				when swap_state_3 =>
					state_r3_reciprocal <= multiply_state_read;
					f_zero              <= bram_f_data_out_a;
					g_zero              <= bram_g_data_out_a;
				when multiply_state_read =>

					bram_f_address_a <= std_logic_vector(to_unsigned(counter_fg, bram_address_width));
					bram_g_address_a <= std_logic_vector(to_unsigned(counter_fg, bram_address_width));
					bram_v_address_a <= std_logic_vector(to_unsigned(counter_vr, bram_address_width));
					bram_r_address_a <= std_logic_vector(to_unsigned(counter_vr, bram_address_width));

					bram_g_address_b_delay(0) <= std_logic_vector(to_unsigned(counter_fg, bram_address_width));
					bram_g_write_b_delay(0)   <= '1';

					bram_r_address_b_delay(0) <= std_logic_vector(to_unsigned(counter_vr, bram_address_width));
					bram_r_write_b_delay(0)   <= '1';

					counter_fg <= counter_fg + 1;
					counter_vr <= counter_vr + 1;
					if counter_fg = p + 1 and counter_vr = p + 1 - 1 then
						state_r3_reciprocal <= multiply_final_state_1;
					else
						state_r3_reciprocal <= multiply_state_read;
					end if;

					-- Shift data in v RAM in all loops except last
					if counter = loop_limit then
						bram_shift_v_write_b <= '0';
					else
						bram_shift_v_write_b <= '0';
						if counter_vr = 1 then
							bram_shift_v_address_b <= (others => '0');
							bram_shift_v_data_in_b <= (others => '0');
							bram_shift_v_write_b   <= '1';
						else
							if counter_vr > 1 then
								bram_shift_v_address_b <= std_logic_vector(to_unsigned(counter_vr - 1, bram_address_width));
								bram_shift_v_data_in_b <= bram_v_data_out_a;
								bram_shift_v_write_b   <= '1';
							end if;
						end if;
					end if;

				when multiply_final_state_1 =>
					bram_g_write_b_delay(0) <= '0';

					bram_r_write_b_delay(0) <= '0';
					state_r3_reciprocal     <= multiply_final_state_2;
					bram_shift_v_write_b    <= '0';

					bram_f_address_a <= (others => '0');
					bram_g_address_a <= (others => '0');
				when multiply_final_state_2 =>
					state_r3_reciprocal     <= running_state;
					bram_shift_v_write_b    <= '0';
					bram_g_write_b_delay(0) <= '0';

					bram_v_address_a <= (others => '0');
					bram_r_address_a <= (others => '0');
				when calc_reciprocal_init =>
					state_r3_reciprocal <= calc_reciprocal_init_2;
					bram_f_address_a    <= (others => '0');
				when calc_reciprocal_init_2 =>
					state_r3_reciprocal <= calc_reciprocal;
				when calc_reciprocal =>
					reciprocal_output   <= bram_f_data_out_a;
					counter_vr          <= 0;
					state_r3_reciprocal <= output_data;
				when output_data =>
					bram_v_address_a     <= std_logic_vector(to_unsigned(p - 1 - counter_vr, bram_address_width));
					counter_vr           <= counter_vr + 1;
					output_valid_pipe(0) <= '1';
					if counter_vr < p then
						state_r3_reciprocal <= output_data;
					else
						state_r3_reciprocal  <= done_state;
						output_valid_pipe(0) <= '0';
					end if;
					if non_zero_mask(delta) = 0 then
						is_invertable <= '1';
					end if;
				when done_state =>
					state_r3_reciprocal  <= init_state;
					output_valid_pipe(0) <= '0';
					done                 <= '1';
			end case;
		end if;
	end process main;

	output_freeze <= "00" when reciprocal_output = "00" or bram_v_data_out_a = "00"
		else "01" when (reciprocal_output = "01" and bram_v_data_out_a = "01") or (reciprocal_output = "11" and bram_v_data_out_a = "11")
		else "11" when (reciprocal_output = "11" and bram_v_data_out_a = "01") or (reciprocal_output = "01" and bram_v_data_out_a = "11")
		else "00";

	output_polynomial <= std_logic_vector(output_freeze);

	delay_output_valid : process(clock, reset) is
	begin
		if reset = '1' then
			output_valid_pipe(pipeline_length downto 1) <= (others => '0');
		elsif rising_edge(clock) then
			output_valid_pipe(pipeline_length downto 1) <= output_valid_pipe(pipeline_length - 1 downto 0);
		end if;
	end process delay_output_valid;

	output_valid <= output_valid_pipe(pipeline_length);

	-- Multiplication of f0*g[i]-g0*f[i]
	g_f0_inter <= "00" when bram_g_data_out_a = "00" or f_zero = "00"
		else "01" when (bram_g_data_out_a = "01" and f_zero = "01") or (bram_g_data_out_a = "11" and f_zero = "11")
		else "11" when (bram_g_data_out_a = "11" and f_zero = "01") or (bram_g_data_out_a = "01" and f_zero = "11")
		else "00";

	f_g0_inter <= "00" when bram_f_data_out_a = "00" or g_zero = "00"
		else "01" when (bram_f_data_out_a = "01" and g_zero = "01") or (bram_f_data_out_a = "11" and g_zero = "11")
		else "11" when (bram_f_data_out_a = "11" and g_zero = "01") or (bram_f_data_out_a = "01" and g_zero = "11")
		else "00";

	fg_freeze <= "00" when g_f0_inter = f_g0_inter
		else "01" when (g_f0_inter = "01" and f_g0_inter = "00") or (g_f0_inter = "11" and f_g0_inter = "01") or (g_f0_inter = "00" and f_g0_inter = "11")
		else "11" when (g_f0_inter = "00" and f_g0_inter = "01") or (g_f0_inter = "01" and f_g0_inter = "11") or (g_f0_inter = "11" and f_g0_inter = "00")
		else "00";

	-- Delay the write to g bram to wait for freeze pipeline to complete.
	-- Also shifts the address by one to implement the shift of g
	delay_bram_g_port_b : process(clock, reset) is
	begin
		if reset = '1' then
			bram_g_address_b_delay(pipeline_length downto 1) <= (others => (others => '0'));
			bram_g_write_b_delay(pipeline_length downto 1)   <= (others => '0');
		else

			if rising_edge(clock) then
				bram_g_address_b_delay(1) <= std_logic_vector(signed(bram_g_address_b_delay(0)) - to_signed(1, bram_address_width));

				if bram_g_address_b_delay(0) = std_logic_vector(to_unsigned(0, bram_address_width)) then
					bram_g_write_b_delay(1) <= '0';
				else
					bram_g_write_b_delay(1) <= bram_g_write_b_delay(0);
				end if;

			end if;
		end if;
	end process delay_bram_g_port_b;

	-- Multiplication of f0*r[i]-g0*v[i]
	r_f0_inter <= "00" when bram_r_data_out_a = "00" or f_zero = "00"
		else "01" when (bram_r_data_out_a = "01" and f_zero = "01") or (bram_r_data_out_a = "11" and f_zero = "11")
		else "11" when (bram_r_data_out_a = "11" and f_zero = "01") or (bram_r_data_out_a = "01" and f_zero = "11")
		else "00";

	v_g0_inter <= "00" when bram_v_data_out_a = "00" or g_zero = "00"
		else "01" when (bram_v_data_out_a = "01" and g_zero = "01") or (bram_v_data_out_a = "11" and g_zero = "11")
		else "11" when (bram_v_data_out_a = "11" and g_zero = "01") or (bram_v_data_out_a = "01" and g_zero = "11")
		else "00";

	vr_freeze <= "00" when r_f0_inter = v_g0_inter
		else "01" when (r_f0_inter = "01" and v_g0_inter = "00") or (r_f0_inter = "11" and v_g0_inter = "01") or (r_f0_inter = "00" and v_g0_inter = "11")
		else "11" when (r_f0_inter = "00" and v_g0_inter = "01") or (r_f0_inter = "01" and v_g0_inter = "11") or (r_f0_inter = "11" and v_g0_inter = "00")
		else "00";

	delay_bram_r_port_b : process(clock, reset) is
	begin
		if reset = '1' then
			bram_r_address_b_delay(pipeline_length downto 1) <= (others => (others => '0'));
			bram_r_write_b_delay(pipeline_length downto 1)   <= (others => '0');
		else
			if rising_edge(clock) then
				bram_r_address_b_delay(pipeline_length downto 1) <= bram_r_address_b_delay(pipeline_length - 1 downto 0);
				bram_r_write_b_delay(pipeline_length downto 1)   <= bram_r_write_b_delay(pipeline_length - 1 downto 0);
			end if;
		end if;
	end process delay_bram_r_port_b;

	bram_f_data_in_b <= (others => '0') when state_r3_reciprocal /= reset_ram and state_r3_reciprocal /= reset_ram_end else bram_f_data_in_b_reset;
	bram_g_data_in_b <= bram_g_data_in_b_reset when state_r3_reciprocal = reset_ram or state_r3_reciprocal = reset_ram_end
		else std_logic_vector(fg_freeze) when bram_g_address_b_delay(pipeline_length) /= std_logic_vector(to_unsigned(p, bram_address_width))
		else (others => '0');
	bram_v_data_in_b <= bram_shift_v_data_in_b when state_r3_reciprocal /= reset_ram and state_r3_reciprocal /= reset_ram_end else bram_v_data_in_b_reset;
	bram_r_data_in_b <= std_logic_vector(vr_freeze) when state_r3_reciprocal /= reset_ram and state_r3_reciprocal /= reset_ram_end else bram_r_data_in_b_reset;

	bram_f_write_b <= '0' when state_r3_reciprocal /= reset_ram and state_r3_reciprocal /= reset_ram_end else bram_f_write_b_reset;
	bram_g_write_b <= bram_g_write_b_delay(pipeline_length) when state_r3_reciprocal /= reset_ram and state_r3_reciprocal /= reset_ram_end else bram_g_write_b_reset;
	bram_v_write_b <= bram_shift_v_write_b when state_r3_reciprocal /= reset_ram and state_r3_reciprocal /= reset_ram_end else bram_v_write_b_reset;
	bram_r_write_b <= bram_r_write_b_delay(pipeline_length) when state_r3_reciprocal /= reset_ram and state_r3_reciprocal /= reset_ram_end else bram_r_write_b_reset;

	bram_f_address_b <= (others => '0') when state_r3_reciprocal /= reset_ram and state_r3_reciprocal /= reset_ram_end else bram_f_address_b_reset;
	bram_g_address_b <= bram_g_address_b_delay(pipeline_length) when state_r3_reciprocal /= reset_ram and state_r3_reciprocal /= reset_ram_end else bram_g_address_b_reset;
	bram_v_address_b <= bram_shift_v_address_b when state_r3_reciprocal /= reset_ram and state_r3_reciprocal /= reset_ram_end else bram_v_address_b_reset;
	bram_r_address_b <= bram_r_address_b_delay(pipeline_length) when state_r3_reciprocal /= reset_ram and state_r3_reciprocal /= reset_ram_end else bram_r_address_b_reset;

	bram_r3_reciprocal : entity work.bram_r3_reciprocal
		generic map(
			bram_address_width => bram_address_width,
			bram_data_width    => 2
		)
		port map(
			clock             => clock,
			swap_mask_s       => swap_mask_s,
			bram_f_address_a  => bram_f_address_a,
			bram_g_address_a  => bram_g_address_a,
			bram_v_address_a  => bram_v_address_a,
			bram_r_address_a  => bram_r_address_a,
			bram_f_data_out_a => bram_f_data_out_a,
			bram_g_data_out_a => bram_g_data_out_a,
			bram_v_data_out_a => bram_v_data_out_a,
			bram_r_data_out_a => bram_r_data_out_a,
			bram_f_data_in_b  => bram_f_data_in_b,
			bram_g_data_in_b  => bram_g_data_in_b,
			bram_v_data_in_b  => bram_v_data_in_b,
			bram_r_data_in_b  => bram_r_data_in_b,
			bram_f_write_b    => bram_f_write_b,
			bram_g_write_b    => bram_g_write_b,
			bram_v_write_b    => bram_v_write_b,
			bram_r_write_b    => bram_r_write_b,
			bram_f_address_b  => bram_f_address_b,
			bram_g_address_b  => bram_g_address_b,
			bram_v_address_b  => bram_v_address_b,
			bram_r_address_b  => bram_r_address_b
		);
end architecture RTL;

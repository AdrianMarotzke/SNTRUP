library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

-- Package for all constants
package constants is

	constant use_2nd_layer_karatsuba : boolean := false;

	type parameter_set_enum is (sntrup653, sntrup761, sntrup857, sntrup953, sntrup1013, sntrup1277);

	constant use_parameter_set : parameter_set_enum := sntrup653; -- only sntrup653 and sntrup761 and sntrup857 are supported so far

	type M_array_Type is array (0 to 41) of integer;

	function set_p return integer;
	function set_q return integer;
	function set_t return integer;
	function set_Rq_bytes return integer;
	function set_Rounded_bytes return integer;
	function set_SecretKey_bytes return integer;
	function set_M_array return M_array_Type;
	function set_radix_width_array return M_array_Type;

	constant p : integer := set_p;

	constant q : integer := set_q;

	constant t : integer := set_t;

	constant Rq_bytes : integer := set_Rq_bytes;

	constant Rounded_bytes : integer := set_Rounded_bytes;

	constant SecretKey_bytes : integer := set_SecretKey_bytes;

	constant M_array : M_array_Type := set_M_array;

	constant radix_width_array : M_array_Type := set_radix_width_array; -- = integer(ceil(log2(real(M_array))));

	constant PublicKeys_bytes : integer := Rq_bytes;

	constant Ciphertexts_bytes : integer := Rounded_bytes;

	constant ct_with_confirm_bytes : integer := Ciphertexts_bytes + 32;

	constant Cipher_bytes_bits : integer := integer(ceil(log2(real(Ciphertexts_bytes + 32 * 2))));

	constant Small_bytes : integer := ((p + 3) / 4);

	constant Small_bytes_bits : integer := integer(ceil(log2(real(Small_bytes))));

	constant q_num_bits : integer := integer(ceil(log2(real(q))));

	constant p_num_bits : integer := integer(ceil(log2(real(p))));

	constant q_half : integer := integer(ceil(real(q) / real(2)));

	constant q12 : integer := (q - 1) / 2;

	constant decode_div_shift : integer := 31;

	constant max_divdend_width : integer := 14 + decode_div_shift;

	constant M_array_squared : M_array_Type := (M_array(0)**2, M_array(0) * M_array(0 + 11),
	                                            M_array(1)**2, M_array(1) * M_array(1 + 11),
	                                            M_array(2)**2, M_array(2) * M_array(2 + 11),
	                                            M_array(3)**2, M_array(3) * M_array(3 + 11),
	                                            M_array(4)**2, M_array(4) * M_array(4 + 11),
	                                            M_array(5)**2, M_array(5) * M_array(5 + 11),
	                                            M_array(6)**2, M_array(6) * M_array(6 + 11),
	                                            M_array(7)**2, M_array(7) * M_array(7 + 11),
	                                            M_array(8)**2, M_array(8) * M_array(8 + 11),
	                                            M_array(9)**2, M_array(9) * M_array(9 + 11),
	                                            0,
	                                            M_array(21)**2, M_array(21) * M_array(21 + 11),
	                                            M_array(22)**2, M_array(22) * M_array(22 + 11),
	                                            M_array(23)**2, M_array(23) * M_array(23 + 11),
	                                            M_array(24)**2, M_array(24) * M_array(24 + 11),
	                                            M_array(25)**2, M_array(25) * M_array(25 + 11),
	                                            M_array(26)**2, M_array(26) * M_array(26 + 11),
	                                            M_array(27)**2, M_array(27) * M_array(27 + 11),
	                                            M_array(28)**2, M_array(28) * M_array(28 + 11),
	                                            M_array(29)**2, M_array(29) * M_array(29 + 11),
	                                            M_array(30)**2, M_array(30) * M_array(30 + 11),
	                                            0
	                                           );

	type decode_divisior_type is array (0 to 41) of unsigned(max_divdend_width downto 0);

	function calc_decode_divisors return decode_divisior_type;

	constant inv_m : decode_divisior_type := calc_decode_divisors; -- precomputes inverse of divisors in M_array

	constant key_encoded_bytes : integer               := 8; -- round 1
	constant radix_int         : integer               := 6144; -- round 1
	constant encoding_radix    : unsigned(63 downto 0) := to_unsigned(radix_int, 64); -- round 1
	constant encoding_batch    : integer               := 5; -- round 1
end package constants;

package body constants is

	-- precomputes inverse of divisors in M_array
	function calc_decode_divisors
	return decode_divisior_type is
		variable value : decode_divisior_type;

		variable decode_division_factor : unsigned(max_divdend_width downto 0) := (others => '0');
	begin
		for i in 0 to 41 loop
			decode_division_factor                                          := (others => '0');
			decode_division_factor(decode_div_shift + radix_width_array(i)) := '1';

			value(i) := decode_division_factor / M_array(i);
			if decode_division_factor mod M_array(i) /= 0 then
				value(i) := value(i) + 1;
			end if;

		end loop;

		return value;
	end function calc_decode_divisors;

	-- Setter functions the select the parameters set

	function set_p
	return integer is
	begin
		case use_parameter_set is
			when sntrup653 =>
				return 653;
			when sntrup761 =>
				return 761;
			when sntrup857 =>
				return 857;
			when others => null;
		end case;

		return 761;
	end function set_p;

	function set_q
	return integer is
	begin
		case use_parameter_set is
			when sntrup653 =>
				return 4621;
			when sntrup761 =>
				return 4591;
			when sntrup857 =>
				return 5167;
			when others => null;
		end case;

		return 4591;
	end function set_q;

	function set_t
	return integer is
	begin
		case use_parameter_set is
			when sntrup653 =>
				return 144;
			when sntrup761 =>
				return 143;
			when sntrup857 =>
				return 161;
			when others => null;
		end case;

		return 143;
	end function set_t;

	function set_Rq_bytes
	return integer is
	begin
		case use_parameter_set is
			when sntrup653 =>
				return 994;
			when sntrup761 =>
				return 1158;
			when sntrup857 =>
				return 1322;
			when others => null;
		end case;

		return 1158;
	end function set_Rq_bytes;

	function set_Rounded_bytes
	return integer is
	begin
		case use_parameter_set is
			when sntrup653 =>
				return 865;
			when sntrup761 =>
				return 1007;
			when sntrup857 =>
				return 1152;
			when others => null;
		end case;

		return 1997;
	end function set_Rounded_bytes;

	function set_SecretKey_bytes
	return integer is
	begin
		case use_parameter_set is
			when sntrup653 =>
				return 1518;
			when sntrup761 =>
				return 1763;
			when sntrup857 =>
				return 1999;
			when others => null;
		end case;

		return 1763;
	end function set_SecretKey_bytes;

	function set_M_array
	return M_array_Type is
	begin
		case use_parameter_set is
			when sntrup653 =>
				return (4621, 326, 416, 676, 1786, 12461, 2370, 86, 7396, 835, 86,
				        4621, 4621, 4621, 7510, 78, 78, 78, 78, 6708, 6708,
				        1541, 9277, 1314, 6745, 695, 1887, 13910, 2953, 134, 71, 2608,
				        1541, 1541, 1531, 7910, 815, 815, 815, 815, 9402, 9402
				       );
			when sntrup761 =>
				return (4591, 322, 406, 644, 1621, 10265, 1608, 10101, 1557, 9470, 1608,
				        4591, 4591, 4591, 4591, 11550, 286, 11468, 282, 11127, 11127,
				        1531, 9157, 1280, 6400, 625, 1526, 9097, 1263, 6232, 593, 3475,
				        1531, 1531, 1531, 1531, 150, 367, 2188, 304, 1500, 1500
				       );
			when sntrup857 =>
				return (5167, 408, 651, 1656, 10713, 1752, 11991, 2194, 74, 5476, 6225,
				        5167, 5167, 5167, 5167, 131, 5483, 5483, 1004, 1004, 291,
				        1723, 11597, 2053, 65, 4225, 273, 292, 334, 436, 743, 160,
				        1723, 1723, 1723, 1723, 438, 7229, 7229, 8246, 8246, 14044
				       );
			when others => null;
		end case;

		return (4591, 322, 406, 644, 1621, 10265, 1608, 10101, 1557, 9470, 1608,
		        4591, 4591, 4591, 4591, 11550, 286, 11468, 282, 11127, 11127,
		        1531, 9157, 1280, 6400, 625, 1526, 9097, 1263, 6232, 593, 3475,
		        1531, 1531, 1531, 1531, 150, 367, 2188, 304, 1500, 1500
		       );
	end function set_M_array;

	function set_radix_width_array
	return M_array_Type is
		variable temp : M_array_Type;

	begin
		for i in 0 to 41 loop
			temp(i) := Integer(ceil(log2(real(M_array(i)))));
		end loop;

		return temp;
	end function set_radix_width_array;

end package body constants;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.sha_512_pkg.all;

entity K_ROM is
	port(
		clock    : in  std_logic;
		address  : in  integer range 0 to 80;
		data_out : out STD_LOGIC_VECTOR(WORD_SIZE - 1 downto 0)
	);
end entity K_ROM;

architecture RTL of K_ROM is
	type rom_type is array (0 to 80) of std_logic_vector(data_out'range);
	signal ROM : rom_type := (
		--address 0
		X"428a2f98d728ae22", X"7137449123ef65cd", X"b5c0fbcfec4d3b2f", X"e9b5dba58189dbbc",
		X"3956c25bf348b538", X"59f111f1b605d019", X"923f82a4af194f9b", X"ab1c5ed5da6d8118",
		X"d807aa98a3030242", X"12835b0145706fbe", X"243185be4ee4b28c", X"550c7dc3d5ffb4e2",
		X"72be5d74f27b896f", X"80deb1fe3b1696b1", X"9bdc06a725c71235", X"c19bf174cf692694",
		X"e49b69c19ef14ad2", X"efbe4786384f25e3", X"0fc19dc68b8cd5b5", X"240ca1cc77ac9c65",
		X"2de92c6f592b0275", X"4a7484aa6ea6e483", X"5cb0a9dcbd41fbd4", X"76f988da831153b5",
		X"983e5152ee66dfab", X"a831c66d2db43210", X"b00327c898fb213f", X"bf597fc7beef0ee4",
		X"c6e00bf33da88fc2", X"d5a79147930aa725", X"06ca6351e003826f", X"142929670a0e6e70",
		X"27b70a8546d22ffc", X"2e1b21385c26c926", X"4d2c6dfc5ac42aed", X"53380d139d95b3df",
		X"650a73548baf63de", X"766a0abb3c77b2a8", X"81c2c92e47edaee6", X"92722c851482353b",
		X"a2bfe8a14cf10364", X"a81a664bbc423001", X"c24b8b70d0f89791", X"c76c51a30654be30",
		X"d192e819d6ef5218", X"d69906245565a910", X"f40e35855771202a", X"106aa07032bbd1b8",
		X"19a4c116b8d2d0c8", X"1e376c085141ab53", X"2748774cdf8eeb99", X"34b0bcb5e19b48a8",
		X"391c0cb3c5c95a63", X"4ed8aa4ae3418acb", X"5b9cca4f7763e373", X"682e6ff3d6b2b8a3",
		X"748f82ee5defb2fc", X"78a5636f43172f60", X"84c87814a1f0ab72", X"8cc702081a6439ec",
		X"90befffa23631e28", X"a4506cebde82bde9", X"bef9a3f7b2c67915", X"c67178f2e372532b",
		X"ca273eceea26619c", X"d186b8c721c0c207", X"eada7dd6cde0eb1e", X"f57d4f7fee6ed178",
		X"06f067aa72176fba", X"0a637dc5a2c898a6", X"113f9804bef90dae", X"1b710b35131c471b",
		X"28db77f523047d84", X"32caab7b40c72493", X"3c9ebe0a15c9bebc", X"431d67c49c100d4c",
		X"4cc5d4becb3e42b6", X"597f299cfc657e2a", X"5fcb6fab3ad6faec", X"6c44198c4a475817", X"0000000000000000"
	);

	attribute ram_style : string;
	attribute ram_style of ROM : signal is "distributed";
begin
	port_a : process(clock) is
	begin
		if rising_edge(clock) then

			data_out <= ROM(address);
		end if;
	end process port_a;

end architecture RTL;

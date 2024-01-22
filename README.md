# A Constant Time Hardware Implementation of Streamlined NTRU Prime

**WARNING This is experimental code, do NOT use in production systems**

This is a constant time hardware implementation of round 3 Streamlined NTRU Prime. This is the code from the paper https://eprint.iacr.org/2020/1067.

The parameter sets `sntrup653`, `sntrup761` and `sntrup857` are currently supported, and can be selected with the constant `use_parameter_set` in the file `constants.pkg.vhd`.

## Performance

Since the paper was published, the code was improved, leading to a reduction of FPGA resources.

The following table contains the performance numbers for the parameter set `sntrup761`:

| Operation       | Cycle Count  | @ 271.6 MHz    |
| :-------------- | :----------: | :----------: | 
| Key Generation  | 1 289 959    | 4748 us      | 
| Encapsulation   | 119 250      | 439 us       | 
| Decapsulation   | 260 307      | 958.2 us       | 

The following table contains the resources utilization:

| Parameter set               | Slices       | LUT          | FF           | BRAM         | DSP          |
| :---------------------------| :----------: | :----------: | :----------: | :----------: | :----------: |
|  sntrup761 - All Operations | 1367         | 7807         | 4144         | 11.5         | 19           |
|  sntrup761 - Only Key Gen   | 1068         | 5935         | 3204         | 8.5          | 12           |
|  sntrup761 - Only Encap     | 844          | 4570         | 2843         | 7.5          | 8            |
|  sntrup761 - Only Decap     | 902          | 5117         | 2958         | 7            | 8            |

## Implementation details

The top module is `ntru_prime_top`, the corrosponding testbench is `tb_ntru_prime_top`.

The testbench is in the folder `tb`. The testbench uses stimulus data gathered from the KAT from the NIST submission of Streamlined NTRU Prime (https://ntruprime.cr.yp.to/nist.html). Data for 50 KAT for the three parameter sets are in folder `tb\tb_stimulus\*`, `tb_ntru_prime_top` will automatically select the correct test data.

The folder sha-512 contains the implementation of the hash function from https://github.com/dsaves/SHA-512, as well as the wrapper used to integrate it into my implementation.

The folder `misc/*` contains some miscellaneous items, such as block ram and stack memory, that are needed across the design.

The folders `encapsulation`, `decapsulation`, `keygen`, `multiplication`, and `encoding` contain the respective vhdl files for that operation.

## Compatibility

This software was originally build with the non-free Vivado `v2018.3.1` tool chain using the `93` standard.

### Free Software support

Experimental support for `synthesis`, `elaborate`, and `run` with `ghdl` is provided using the `Makefile`:
```
mkdir build && cd build
make -f ../Makefile synthesis
make -f ../Makefile elaborate
make -f ../Makefile run
```

Using `ghdl` version `4.0.0` or `ghdl` from `git tip` with `llvm` should be functional.

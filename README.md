# A Constant Time Hardware Implementation of Streamlined NTRU Prime
This is a constant time hardware implementation of round 3 Streamlined NTRU Prime. This is the code from the paper https://eprint.iacr.org/2020/1067.

The parameter sets sntrup653, sntrup761 and sntrup857 are currently supported, and can be selected with the constant "use_parameter_set" in the file constants.pkg.vhd.

Since the paper was published, the code was improved, leading to a reduction of FPGA resources.

The following table contains the performance numbers for the parameter set sntrup761:

| Operation       | Cycle Count  | @ 269 MHz    |
| :-------------- | :----------: | :----------: | 
| Key Generation  | 1 304 742    | 4847 us      | 
| Encapsulation   | 142 238      | 528 us       | 
| Decapsulation   | 259 945      | 965 us       | 

The following table contains the resources utilization:

| Parameter set  | Slices       | LUT          | FF           | BRAM         | DSP          |
| :------------- | :----------: | :----------: | :----------: | :----------: | :----------: |
|  sntrup761     | 1596         | 8933         | 5221         | 13           |19            |

The top module is ntru_prime_top, the corrosponding testbench is tb_ntru_prime_top.

The testbench is in the folder tb. The testbench uses stimulus data gathered from the KAT from the NIST submission of Streamlined NTRU Prime (https://ntruprime.cr.yp.to/nist.html). Data for 50 KAT for the three parameter sets are in folder tb\tb_stimulus\, tb_ntru_prime_top will automatically select the correct test data.

The folder sha-512 contains the implementation of the hash function from https://github.com/dsaves/SHA-512, as well as the wrapper used to integrate it into my implementation.

The folder misc contains some miscellaneous items, such as block ram and stack memory, that are need across the design.

The folders encapsulation, decapsulation, keygen, multiplication and encoding contain the respective vhdl files for that operation.


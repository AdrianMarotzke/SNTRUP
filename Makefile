GHDLFLAGS=-v -fsynopsys -frelaxed-rules -Wl,-Wl,--gc-sections -fexplicit --ieee=synopsys --syn-binding --vital-checks --std=93 -frelaxed
synthesis:
	ghdl -a ${GHDLFLAGS} \
	 ../constants.pkg.vhd \
	 ../data_type.pkg.vhd \
	 ../misc/block_ram.vhd \
	 ../misc/stack_memory.vhd \
	 ../misc/FIFO_buffer.vhd \
	 ../misc/comparator.vhd \
	 ../misc/sort_bram.vhd \
	 ../misc/small_random_weights.vhd \
	 ../misc/mod3_freeze.vhd \
	 ../misc/modq_freeze.vhd \
	 ../misc/SDP_dist_RAM.vhd \
	 ../misc/sort_bram.vhd \
	 ../misc/small_random_weights.vhd \
	 ../encoding/division_32_by_const.vhd \
	 ../encoding/div_mod_pipeline.vhd \
	 ../encoding/encode_R3.vhd \
	 ../encoding/division_32_by_const.vhd \
	 ../encoding/div_mod_pipeline.vhd \
 	 ../encoding/decode_Rq.vhd \
	 ../encoding/decode_R3.vhd \
	 ../encoding/encode_R3.vhd \
	 ../encoding/encode_Rq.vhd \
	 ../multiplication/rq_mult_generic_3bit.vhd \
	 ../multiplication/rq_mult_generic_4bit.vhd \
	 ../multiplication/rq_mult_generic.vhd \
	 ../multiplication/rq_mult_generic_x3_3bit.vhd \
	 ../multiplication/rq_mult_generic_x3.vhd \
	 ../multiplication/rq_mult_karatsuba_2bit_2nd_layer.vhd \
	 ../multiplication/rq_mult_karatsuba_3bit_2nd_layer.vhd \
	 ../multiplication/rq_mult_karatsuba.vhd \
	 ../encapsulation/key_encapsulation.vhd \
	 ../encapsulation/key_encap_wrapper.vhd \
	 ../decapsulation/rq_mult3.vhd \
	 ../decapsulation/calc_weight.vhd \
	 ../decapsulation/key_decapsulation.vhd \
	 ../decapsulation/key_decap_wrapper.vhd \
	 ../sha_512/sha_512_pkg.vhdl \
	 ../sha_512/ROM.vhd \
	 ../sha_512/sha_512_core.vhdl \
	 ../sha_512/sha_512_wrapper.vhd \
	 ../keygen/bram_r3_reciprocal.vhd \
	 ../keygen/bram_rq_reciprocal_3.vhd \
	 ../keygen/modq_reciprocal.vhd \
	 ../keygen/r3_reciprocal.vhd \
	 ../keygen/modq_minus_product.vhd \
	 ../keygen/modq_reciprocal.vhd \
	 ../keygen/rq_reciprocal_3.vhd \
	 ../keygen/key_generation.vhd \
	 ../keygen/key_gen_wrapper.vhd \
	 ../ntru_prime_top.vhd \
	 ../tb/tb_ntru_prime_top.vhd


elaborate:
	ghdl -e ${GHDLFLAGS} FIFO_buffer
	ghdl -e ${GHDLFLAGS} comparator
	ghdl -e ${GHDLFLAGS} sort_bram
	ghdl -e ${GHDLFLAGS} small_random_weights
	ghdl -e ${GHDLFLAGS} block_ram
	ghdl -e ${GHDLFLAGS} K_ROM
	ghdl -e ${GHDLFLAGS} FIFO_buffer
	ghdl -e ${GHDLFLAGS} mod3_freeze
	ghdl -e ${GHDLFLAGS} modq_freeze
	ghdl -e ${GHDLFLAGS} SDP_dist_RAM
	ghdl -e ${GHDLFLAGS} stack_memory
	ghdl -e ${GHDLFLAGS} modq_reciprocal
	ghdl -e ${GHDLFLAGS} bram_r3_reciprocal
	ghdl -e ${GHDLFLAGS} bram_rq_reciprocal_3
	ghdl -e ${GHDLFLAGS} r3_reciprocal
	ghdl -e ${GHDLFLAGS} modq_minus_product
	ghdl -e ${GHDLFLAGS} modq_reciprocal
	ghdl -e ${GHDLFLAGS} rq_reciprocal_3
	ghdl -e ${GHDLFLAGS} encode_R3
	ghdl -e ${GHDLFLAGS} key_gen_wrapper
	ghdl -e ${GHDLFLAGS} rq_reciprocal_3
	ghdl -e ${GHDLFLAGS} division_32_by_const
	ghdl -e ${GHDLFLAGS} decode_Rq
	ghdl -e ${GHDLFLAGS} div_mod_pipeline
	ghdl -e ${GHDLFLAGS} decode_R3
	ghdl -e ${GHDLFLAGS} division_32_by_const
	ghdl -e ${GHDLFLAGS} div_mod_pipeline
	ghdl -e ${GHDLFLAGS} encode_R3
	ghdl -e ${GHDLFLAGS} encode_Rq
	ghdl -e ${GHDLFLAGS} rq_mult_generic_3bit
	ghdl -e ${GHDLFLAGS} rq_mult_generic_4bit
	ghdl -e ${GHDLFLAGS} rq_mult_generic
	ghdl -e ${GHDLFLAGS} rq_mult_generic_x3_3bit
	ghdl -e ${GHDLFLAGS} rq_mult_generic_x3
	ghdl -e ${GHDLFLAGS} rq_mult_karatsuba_2bit_2nd_layer
	ghdl -e ${GHDLFLAGS} rq_mult_karatsuba_3bit_2nd_layer
	ghdl -e ${GHDLFLAGS} rq_mult_karatsuba_2bit
	ghdl -e ${GHDLFLAGS} key_encapsulation
	ghdl -e ${GHDLFLAGS} key_encap_wrapper
	ghdl -e ${GHDLFLAGS} rq_mult3
	ghdl -e ${GHDLFLAGS} calc_weight
	ghdl -e ${GHDLFLAGS} key_decapsulation
	ghdl -e ${GHDLFLAGS} key_decap_wrapper
	ghdl -e ${GHDLFLAGS} key_generation
	ghdl -e ${GHDLFLAGS} K_ROM
	ghdl -e ${GHDLFLAGS} sha_512_core
	ghdl -e ${GHDLFLAGS} sha_512_wrapper
	ghdl -e ${GHDLFLAGS} ntru_prime_top
	ghdl -e ${GHDLFLAGS} tb_ntru_prime_top

clean:
	-rm *.o
	-rm *.cf

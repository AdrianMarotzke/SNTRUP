GHDLFLAGS=-fsynopsys
synthesis:
	ghdl -a ${GHDLFLAGS} ../constants.pkg.vhd
	ghdl -a ${GHDLFLAGS} ../data_type.pkg.vhd
	ghdl -a ${GHDLFLAGS} ../misc/FIFO_buffer.vhd
	ghdl -a ${GHDLFLAGS} ../misc/comparator.vhd
	ghdl -a ${GHDLFLAGS} ../misc/sort_bram.vhd
	ghdl -a ${GHDLFLAGS} ../misc/block_ram.vhd
	ghdl -a ${GHDLFLAGS} ../misc/small_random_weights.vhd
	ghdl -a ${GHDLFLAGS} ../misc/FIFO_buffer.vhd
	ghdl -a ${GHDLFLAGS} ../misc/mod3_freeze.vhd
	ghdl -a ${GHDLFLAGS} ../misc/modq_freeze.vhd
	ghdl -a ${GHDLFLAGS} ../misc/SDP_dist_RAM.vhd
	ghdl -a ${GHDLFLAGS} ../misc/small_random_weights.vhd
	ghdl -a ${GHDLFLAGS} ../misc/sort_bram.vhd
	ghdl -a ${GHDLFLAGS} ../misc/stack_memory.vhd
	ghdl -a ${GHDLFLAGS} ../keygen/modq_reciprocal.vhd
	ghdl -a ${GHDLFLAGS} ../keygen/bram_r3_reciprocal.vhd
	ghdl -a ${GHDLFLAGS} ../keygen/bram_rq_reciprocal_3.vhd
	ghdl -a ${GHDLFLAGS} ../keygen/r3_reciprocal.vhd
	ghdl -a ${GHDLFLAGS} ../keygen/modq_minus_product.vhd
	ghdl -a ${GHDLFLAGS} ../keygen/modq_reciprocal.vhd
	ghdl -a ${GHDLFLAGS} ../keygen/rq_reciprocal_3.vhd
	ghdl -a ${GHDLFLAGS} ../keygen/key_generation.vhd
	ghdl -a ${GHDLFLAGS} ../encoding/encode_R3.vhd 
	ghdl -a ${GHDLFLAGS} ../keygen/key_gen_wrapper.vhd
	ghdl -a ${GHDLFLAGS} ../keygen/rq_reciprocal_3.vhd
	ghdl -a ${GHDLFLAGS} ../encoding/division_32_by_const.vhd
	ghdl -a ${GHDLFLAGS} ../encoding/div_mod_pipeline.vhd
	ghdl -a ${GHDLFLAGS} ../encoding/decode_R3.vhd
	ghdl -a ${GHDLFLAGS} ../encoding/decode_Rq.vhd
	ghdl -a ${GHDLFLAGS} ../encoding/division_32_by_const.vhd
	ghdl -a ${GHDLFLAGS} ../encoding/div_mod_pipeline.vhd
	ghdl -a ${GHDLFLAGS} ../encoding/encode_R3.vhd
	ghdl -a ${GHDLFLAGS} ../encoding/encode_Rq.vhd
	ghdl -a ${GHDLFLAGS} ../multiplication/rq_mult_generic_3bit.vhd
	ghdl -a ${GHDLFLAGS} ../multiplication/rq_mult_generic_4bit.vhd
	ghdl -a ${GHDLFLAGS} ../multiplication/rq_mult_generic.vhd
	ghdl -a ${GHDLFLAGS} ../multiplication/rq_mult_generic_x3_3bit.vhd
	ghdl -a ${GHDLFLAGS} ../multiplication/rq_mult_generic_x3.vhd
	ghdl -a ${GHDLFLAGS} ../multiplication/rq_mult_karatsuba_2bit_2nd_layer.vhd
	ghdl -a ${GHDLFLAGS} ../multiplication/rq_mult_karatsuba_3bit_2nd_layer.vhd
	ghdl -a ${GHDLFLAGS} ../multiplication/rq_mult_karatsuba.vhd
	ghdl -a ${GHDLFLAGS} ../encapsulation/key_encapsulation.vhd
	ghdl -a ${GHDLFLAGS} ../encapsulation/key_encap_wrapper.vhd
	ghdl -a ${GHDLFLAGS} ../decapsulation/rq_mult3.vhd
	ghdl -a ${GHDLFLAGS} ../decapsulation/calc_weight.vhd
	ghdl -a ${GHDLFLAGS} ../decapsulation/key_decapsulation.vhd
	ghdl -a ${GHDLFLAGS} ../decapsulation/key_decap_wrapper.vhd
	ghdl -a ${GHDLFLAGS} ../sha_512/sha_512_pkg.vhdl
	ghdl -a ${GHDLFLAGS} ../sha_512/ROM.vhd
	ghdl -a ${GHDLFLAGS} ../sha_512/sha_512_core.vhdl
	ghdl -a ${GHDLFLAGS} ../sha_512/sha_512_wrapper.vhd
	ghdl -a ${GHDLFLAGS} ../ntru_prime_top.vhd
	ghdl -a ${GHDLFLAGS} ../tb/tb_ntru_prime_top.vhd

clean:
	-rm *.o
	-rm *.cf

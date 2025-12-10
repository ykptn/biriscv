.PHONY: tb_cbm tb_cbm_clean tb_dot_mul tb_dot_mul_clean tb_matrix_mul tb_matrix_mul_clean tb_poly_horner_mul tb_poly_horner_mul_clean tb_fft_mul tb_fft_mul_clean

tb_cbm:
	$(MAKE) -C tb/tb_cbm run

tb_cbm_clean:
	$(MAKE) -C tb/tb_cbm clean

tb_dot_mul:
	$(MAKE) -C tb/tb_dot_mul run

tb_dot_mul_clean:
	$(MAKE) -C tb/tb_dot_mul clean

tb_matrix_mul:
	$(MAKE) -C tb/tb_matrix_mul run

tb_matrix_mul_clean:
	$(MAKE) -C tb/tb_matrix_mul clean

tb_poly_horner_mul:
	$(MAKE) -C tb/tb_poly_horner_mul run

tb_poly_horner_mul_clean:
	$(MAKE) -C tb/tb_poly_horner_mul clean

tb_fft_mul:
	$(MAKE) -C tb/tb_fft_mul run

tb_fft_mul_clean:
	$(MAKE) -C tb/tb_fft_mul clean

.PHONY: tb_cbm tb_cbm_clean

tb_cbm:
	$(MAKE) -C tb/tb_cbm run

tb_cbm_clean:
	$(MAKE) -C tb/tb_cbm clean

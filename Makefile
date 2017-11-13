ASSEMBLY_FILES=$(wildcard *.asm)
ASSEMBLY_BINS=$(ASSEMBLY_FILES:.asm=)

$(ASSEMBLY_BINS): $(ASSEMBLY_FILES)
	nasm $<

clean:
	rm -f $(ASSEMBLY_BINS)

.PHONY: clean

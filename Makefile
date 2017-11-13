MAKEFLAGS += --no-builtin-rules
ASSEMBLY_FILES=$(wildcard *.asm)
ASSEMBLY_BINS=$(ASSEMBLY_FILES:.asm=.o)
KERNEL_BIN=kernel.bin
LINK_SCRIPT=linker.ld

$(KERNEL_BIN): $(ASSEMBLY_BINS)
	ld -n -o $@ -T $(LINK_SCRIPT) $(ASSEMBLY_BINS)

%.o: %.asm
	nasm -f elf64 $< -o $(<:.asm=.o)

clean:
	rm -f $(ASSEMBLY_BINS) $(KERNEL_BIN)

.PHONY: clean

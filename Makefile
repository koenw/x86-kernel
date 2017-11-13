MAKEFLAGS += --no-builtin-rules
ASSEMBLY_FILES=$(wildcard *.asm)
ASSEMBLY_BINS=$(ASSEMBLY_FILES:.asm=.o)
KERNEL_BIN=kernel.bin
LINK_SCRIPT=linker.ld
ISO_DIR=iso
ISO_NAME=kernel.iso

$(KERNEL_BIN): $(ASSEMBLY_BINS)
	ld -n -o $@ -T $(LINK_SCRIPT) $(ASSEMBLY_BINS)

%.o: %.asm
	nasm -f elf64 $< -o $(<:.asm=.o)

$(ISO_DIR)/boot/grub/grub.cfg:
	mkdir -p $(ISO_DIR)/boot/grub
	echo "$$GRUBCFG" > $@

$(ISO_DIR)/boot/$(KERNEL_BIN): $(KERNEL_BIN)
	cp $(KERNEL_BIN) $@

kernel.iso: $(ISO_DIR)/boot/grub/grub.cfg $(ISO_DIR)/boot/$(KERNEL_BIN)
	grub-mkrescue -o $@ $(ISO_DIR)

iso: $(ISO_NAME)

run: $(ISO_NAME)
	qemu-system-x86_64 -cdrom $(ISO_NAME)

clean:
	rm -rf $(ASSEMBLY_BINS) $(KERNEL_BIN) $(ISO_DIR) $(ISO_NAME)

.PHONY: clean iso run

define GRUBCFG
set timeout=0
set default=0

menuentry "minimal kernel" {
	multiboot2 /boot/$(KERNEL_BIN)
	boot
}
endef
export GRUBCFG

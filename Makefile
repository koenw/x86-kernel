arch ?= x86_64
rust_target ?= $(arch)-rust_kernel
rust_kernel = target/$(rust_target)/debug/librust_kernel.a
build_dir ?= build

iso = $(build_dir)/os-$(arch).iso
kernel_name = kernel-$(arch).bin
kernel = $(build_dir)/$(kernel_name)
linker_script = src/arch/$(arch)/linker.ld

rust_sources=$(wildcard src/*.rs)

assembly_sources=$(wildcard src/arch/$(arch)/*.asm)
assembly_objects=$(patsubst src/arch/$(arch)/%.asm, $(build_dir)/arch/$(arch)/%.o, $(assembly_sources))

$(kernel): $(assembly_objects) $(linker_script) $(rust_kernel)
	ld -n --gc-sections -o $@ -T $(linker_script) $(assembly_objects) $(rust_kernel)

$(rust_kernel): $(rust_sources) Cargo.toml $(rust_target).json
	xargo build --target $(rust_target)

iso: $(iso)

run: $(iso)
	qemu-system-x86_64 -cdrom $(iso)

clean:
	cargo clean
	rm -rf $(build_dir)

$(build_dir)/arch/$(arch)/%.o: src/arch/$(arch)/%.asm $(build_dir)/arch/$(arch)
	nasm -f elf64 $< -o $@

$(build_dir)/arch/$(arch):
	mkdir -p $@

$(iso): $(build_dir)/iso/boot/grub/grub.cfg $(build_dir)/iso/boot/$(kernel_name) $(rust_kernel)
	grub-mkrescue -o $@ $(build_dir)/iso

$(build_dir)/iso/boot/grub/grub.cfg:
	mkdir -p $(build_dir)/iso//boot/grub
	echo "$$GRUBCFG" > $@

$(build_dir)/iso/boot/$(kernel_name): $(kernel)
	cp $(kernel) $@

.PHONY: clean iso run

define GRUBCFG
set timeout=0
set default=0

menuentry "minimal kernel" {
	multiboot2 /boot/$(kernel_name)
	boot
}
endef
export GRUBCFG

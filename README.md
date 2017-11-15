# A minimal x86 kernel

Writing a minimal x86 kernel in (intel) assembler and rust, with
https://os.phil-opp.com/multiboot-kernel/. See
https://github.com/phil-opp/blog_os for the original repo.

## Table of Contents

   * [A minimal x86 kernel](#a-minimal-x86-kernel)
      * [Requirements](#requirements)
      * [Usage](#usage)
      * [Notes](#notes)
         * [The multiboot header](#the-multiboot-header)
         * [Some executable code](#some-executable-code)
         * [Creating an executable](#creating-an-executable)
         * [Creating a bootable ISO](#creating-a-bootable-iso)
         * [Booting our kernel](#booting-our-kernel)
         * [Putting it all together in a Makefile](#putting-it-all-together-in-a-makefile)

## Requirements

* nasm for assembling
* ld for linking
* make
* grub to create a bootable iso
* xorriso (libisoburn package) to create a bootable iso
* qemu to run our kernel in a VM

## Usage

| Command | Description |
|---------|-------------|
|`make` | Build the kernel |
|`make iso` | Create a bootable iso image |
|`make run` | Boot our kernel in a VM |
|`make clean` | Clean the working directory from build artifacts |

## Notes

### The multiboot header

Most bootloaders are compatible with the [Multiboot
Specification](https://en.wikipedia.org/wiki/Multiboot_Specification). This
means that if our kernel implements the multiboot specification, most generic
bootloaders will be able to boot our kernel.

To indicate that our kernel supports Multiboot 2, our kernel must start with
the following _Multiboot Header_:

|Field|Type|Value|
|---|---|---|
|magic number|u32|`0xE85250D6`|
|architecture|u32|`0` for i386|
|header length|u32|total header size, including tags|
|checksum|u32|`-(magic + architecture + header_length)`|
|tags|variable||
|end tag|(u16, u16, u32)|`(0, 0, 9)`

#### Putting it into Assembly

`multiboot_header.asm`:
```nasm
section .multiboot_header
; tag the start and end of the header, so we can determine the size of the
; header.
header_start:
  dd 0xe85250d6                 ; magic number
  dd 0                          ; protected mode i386
  dd header_end - header_start  ; header length
  dd 0x100000000 - (0xe85250d6 + 0 + (header_end - header_start)) ; checksum

  ; insert optional tags here

  ; end tag
  dw 0 ; type
  dw 0 ; flags
  dd 8 ; size
header_end:
```

### Some executable code

To keep it simple, we will just write _OK_ to the screen for now. We can do
this by simply writing the bytes we want to display the the VGA buffer, at
offset `0xb8000`. We will do this in 32 bits assembly, since the CPU is still
in _Protected Mode_ when the bootloader starts our kernel.

`boot.asm`:
```nasm
; We will call `start` from outside (e.g. from the bootloader), so we will
; export it
global start

section .text
bits 32
start:
  ; print  `OK` to the screen
  mov dword [0xb8000], 0x2f4b2f4f
  hlt
```

### Creating an executable

First, we assemble our `boot.asm` and `multiboot_header.asm` in ELF64 format:
```sh
nasm -f elf64 -o multiboot_header.o multiboot_header.asm
nasm -f elf64 -o boot.o boot.asm
```

Next, we'll need to link our two binaries (`boot.o` and `multibooot_header.o`)
together to create a single binary. Because we need some control over what
endsup where, we'll use a custom linker script (`linker.ld`):

```Linker Script
/* the entrypoint is the 'start' label from our boot.asm, this is where
 * execution of our kernel will begin */
ENTRY(start)

SECTIONS {
  /* set the load address of the first section to 1MiB, which is a common
   * place to load a kernel. Lower addresses can be used for special
   * purposes, like the VGA buffer */
  . = 1M;

  .boot :
  {
    /* ensure that the multiboot header is at the beginning */
    *(.multiboot_header)
  }

  .text :
  {
    /* the text section will just include the text section from our boot.asm */
    *(.text)
  }
}
```

In addition to using our custom linker script, we'll also need to tell the
linker to not try to our sections (.e.g. the `.boot` section) to page
boundaries, or grub might be unable to find it. We do this by passing `-n` to
the linker.

The final command to link everything together becomes:
```sh
  ld -n -o kernel.bin -T linker.ld boot.o multiboot_header.o
```

We should now have a bootable kernel in `kernel.bin`!

### Creating a bootable ISO

Grub comes with a utility, `grub-mkrescue`, that makes it easy to create a
bootable iso image. Under the hood, `grub-mkrescue` uses `xorriso` to actually
create the ISO 9660 filesystem, so you'll need to have that installed too.
(And alternative, if you're feeling adventurous, you could use xorriso directly
to create your ISO image).

Creating a bootable grub ISO is as easy as creating a directory tree with a
grug.cfg and a kernel, and passing it to `grub-mkrescue`:

```sh
ISO_ROOT=./iso_root
KERNEL=./kernel.bin

# Create the boot and boot/grub directories
mkdir -p "${ISO_ROOT}/boot/grub"

# Create grub.cfg
cat <<EOF > "${ISO_ROOT}/boot/grub/grub.cfg"
set timeout=0
set default=0

menuentry "minimal kernel" {
  multiboot2 /boot/$(basename ${KERNEL})
  boot
}
EOF

# Copy our kernel
cp "$KERNEL" "${ISO_ROOT}/boot/$(basename ${KERNEL})"

# Make a bootable iso from our directory
grub-mkrescue -o kernel.iso "$ISO_ROOT"
```

We should now have a bootable ISO that will print `OK` to the screen when
booted!

### Booting our kernel

You can easily test your kernel by booting from our ISO in a Virtual Machine:

```sh
qemu-system-x86_64 -cdrom kernel.iso
```

### Putting it all together in a `Makefile`

Since we don't want to run all these `nasm`, `ld`, etc commands every time we
change something, we will create a Makefile to do these things for us.
Basically, we tell `Make` what the dependencies between files are (e.g. `boot.o`
depends on `boot.asm` and `kernel.iso` depends on `kernel.bin`), and how to
create each file. When we invoke `Make`, Make will check what files have
changed, and so will know what files need to be re-created because their
dependencies changed.

Instead of writing out all dependencies by hand, we'll make use of some Make
features like wildcards that I will not explain here, but there are plenty of
tutorials that explain these in more depth.

```Makefile
MAKEFLAGS += --no-builtin-rules
ASSEMBLY_FILES=$(wildcard *.asm)
ASSEMBLY_BINS=$(ASSEMBLY_FILES:.asm=.o)
KERNEL_BIN=kernel.bin
LINK_SCRIPT=linker.ld
ISO_DIR=iso
ISO_NAME=kernel.iso

# The file ('target') kernel.bin depends boot.o and multiboot_header.o, and
# can be created by running the linker command below. This should be TAB
# indented, or Make will barf) # $@ is expended to the target (i.e. 'kernel.bin')
$(KERNEL_BIN): $(ASSEMBLY_BINS)
	ld -n -o $@ -T $(LINK_SCRIPT) $(ASSEMBLY_BINS)

# Files ending in `.o` depend on files ending in `.asm`
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

# Tell make 'clean', 'iso' and 'run' aren't actually files
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
```

You can now invoke `Make` with a particular target, .e.g. `make run`, and Make
will automatically know what needs to be done.

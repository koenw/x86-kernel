# A minimal x86 kernel

Writing a minimal x86 kernel in (intel) assembler and rust, with
https://os.phil-opp.com/multiboot-kernel/.

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

### Some executable code

To keep it simple, we will just write _OK_ to the screen for now. We can do
this by simply writing the bytes we want to display the the VGA buffer, at
offset `0xb8000`. We will do this in 32 bits assembly, since the CPU is still
in _Protected Mode_ when the bootloader starts our kernel.

```Assembly
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

The bootloader expects an ELF executable, so we will use the linker to create
an ELF binary that includes the multiboot header and afterwards our code:

```Linker Script
/* the entrypoint is the 'start' section, this is where execution
 * of our kernel will begin */
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

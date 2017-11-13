# A minimal x86 kernel

Writing a minimal x86 kernel in (intel) assembler and rust, with
https://os.phil-opp.com/multiboot-kernel/.

## Requirements

* nasm for assembling assembly
* make

## Notes

Most bootloaders are compatible with the [Multiboot
Specification](https://en.wikipedia.org/wiki/Multiboot_Specification). This
means that if our kernel implements the multiboot specification, most generic
bootloaders will be able to boot our kernel.

To indicate that our kernel supports Multiboot 2, our kernel must start with the following _Multiboot Header_:

|Field|Type|Value|
|---|---|---|
|magic number|u32|`0xE85250D6`|
|architecture|u32|`0` for i386|
|header length|u32|total header size, including tags|
|checksum|u32|`-(magic + architecture | header_length)`|
|tags|variable||
|end tag|(u16, u16, u32)|`(0, 0, 9)`

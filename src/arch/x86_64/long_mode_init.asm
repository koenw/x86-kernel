; 64 bit mode
global long_mode_start

section .text
bits 64
long_mode_start:
  ; Some instructions expect a valid descriptor or the null descriptor in the
  ; `ss`, `ds`, `es`, `fs` and/or `gs` registers. We've updated the `cs`
  ; register with our new GDT offset, but these references still contain the
  ; data segment offsets of the old GDT. Hence, we'll load 0 into them.
  mov ax, 0
  mov ss, ax
  mov ds, ax
  mov es, ax
  mov fs, ax
  mov gs, ax

  ; call the rust main
  extern rust_main
  call rust_main

  ; print `OKAY` to the screen
  mov rax, 0x2f592f412f4b2f4f
  mov qword [0xb8000], rax
  hlt

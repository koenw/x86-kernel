global start

section .text
bits 32
start:
  ; Move the stackpointer to the top of our stack
  mov esp, stack_top

  call check_multiboot
  call check_cpuid
  call check_long_mode

  call setup_page_tables
  call enable_paging

  ; print  `OK` to the screen
  mov dword [0xb8000], 0x2f4b2f4f
  hlt

; Prints `Err: ` and the given error code to screen and hangs.
; parameters: error code (in ascii) in al.
die:
  mov dword [0xb8000], 0x4f524f45
  mov dword [0xb8004], 0x4f3a4f52
  mov dword [0xb8008], 0x4f204f20
  mov byte [0xb800a], al
  hlt

; Because we will later rely on some multiboot features, we will check if we
; were loaded by a multiboot compliant bootloader. According to the multiboot
; spec, the bootloader must write the magic number 0x36d76289 to the eax register
; before loading the kernel.
check_multiboot:
  cmp eax, 0x36d76289
  jne .no_multiboot
  ret
.no_multiboot:
  mov al, "0"
  jmp die

; Check if CPUID is supported by the CPU. We need CPUID to check if the CPU
; supports Long Mode before we jump to it.
; http://wiki.osdev.org/Setting_Up_Long_Mode#Detection_of_CPUID
check_cpuid:
  ; Check if CPUID is supported by attempting to flip the ID bit (bit 21)
  ; in the FLAGS register. If we can flip it, CPUID is available.

  ; Copy FLAGS into the EAX via the stack
  pushfd
  pop eax

  ; Copy to ECX as well to later compare it to
  mov ecx, eax

  ; Flip the ID bit
  xor eax, 1<<21

  ; Copy EAX to FLAGS via the stack
  push eax
  popfd

  ; Restore FLAGS from the old version stored in ecx (i.e. flipping the ID bit
  ; back if it was flipped).
  push ecx
  popfd

  ; Compare EAX and ECX. If they're equal the bit wasn't flipped, and CPUID is
  ; not supported.
  cmp eax, ecx
  je .no_cpuid
  ret
.no_cpuid:
  mov al, "1"
  jmp die

; Check if the CPU supports long mode: http://wiki.osdev.org/Setting_Up_Long_Mode#x86_or_x86-64
check_long_mode:
  ; test if extended processor info is available
  mov eax, 0x80000000   ; implicit argument for cpuid
  cpuid                 ; get highest supported argument
  cmp eax, 0x80000001   ; it needs to be at least 0x80000001
  jb .no_long_mode      ; if it's less, the CPU does not support long mode

  ; use extened info to test if long mode is available
  mov eax, 0x80000001   ; argument for extended processor info
  cpuid
  test edx, 1 << 29     ; test if the long-mode-bit is set in the D-register
  jz .no_long_mode      ; if it's not set, the CPU does not support long mode
  ret
.no_long_mode:
  mov al, "2"
  jmp die

; At the time we're loaded, the .bss section gets created in memory and
; initialized to 0. So, in order to be able to use our page tables, we'll have
; to initialize them. For simplicities sake, we will just use huge pages in P2,
; so  we have 2MiB pages.
setup_page_tables:
  ; map the first P4 entry to the P3 table
  mov eax, p3_table
  or eax, 0b11      ; present + writable
  mov [p4_table], eax

  ; map the first P3 entry to the P2 table
  mov eax, p2_table
  or eax, 0b11      ; present + writeable
  mov [p3_table], eax

  ; map each P2 entry to a huge 2MiB page
  mov ecx, 0
.map_p2_table:
  ; map exc-th P2 entry to a huge page that starts at address 2MiB*exc
  mov eax, 0x200000   ; 2MiB
  mul ecx             ; start address of ecx-th page
  or eax, 0b10000011  ; present + writeable + huge
  mov [p2_table + ecx * 8], eax ; map exc-th entry

  inc ecx             ; increase loop counter
  cmp ecx, 512        ; if counter == 512, the whole P2 table is mapped
  jne .map_p2_table

  ret

enable_paging:
  ; load P4 to cr3 register (cpu uses the cr3 register to access the P4 table)
  mov eax, p4_table
  mov cr3, eax

  ; enable the PAE (Physical Address Extention) flag in cr4 (long mode is a subset of the PAE)
  mov eax, cr4
  or eax, 1 << 5
  mov cr4, eax

  ; set the long mode bit in the EFER MSR (model specific register)
  mov ecx, 0xC0000080
  rdmsr
  or eax, 1 << 8
  wrmsr

  ; enable paging in the cr0 register
  mov eax, cr0
  or eax, 1 << 31
  mov cr0, eax

  ret

; The program loader (grub in our case) will allocate memory for the bss
; section when we're loaded.
section .bss
align 4096
p4_table:
  resb 4096
p3_table:
  resb 4096
p2_table:
  resb 4096
stack_bottom:
  ; reserve 64 bytes in this section
  resb 64
stack_top:

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

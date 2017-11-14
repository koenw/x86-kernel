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
    KEEP(*(.multiboot_header))
  }

  .text :
  {
    *(.text)
  }
}

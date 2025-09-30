import os

const ripemd160Path = currentSourcePath().parentDir() / "deps/ripemd-160"

when defined(emscripten):
  {.compile: ripemd160Path / "rmd160.c".}
else:
  {.compile: ripemd160Path / "rmd160_64.c".}

proc MDinit*(MDbuf: ptr array[5, uint32]) {.importc.}
proc MDfinish*(MDbuf: ptr array[5, uint32], strptr: ptr UncheckedArray[byte], lswlen: uint32, mswlen: uint32) {.importc.}

proc ripemd160*(data: ptr UncheckedArray[byte], size: uint32): array[20, byte] {.inline.} =
  MDinit(cast[ptr array[5, uint32]](addr result))
  MDfinish(cast[ptr array[5, uint32]](addr result), data, size, 0)

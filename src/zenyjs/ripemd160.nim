# Copyright (c) 2025 zenywallet

when defined(js):
  {.error: "not implemented".}

else:
  when defined(emscripten):
    {.compile: "../../deps/ripemd-160/rmd160.c".}
  else:
    {.compile: "../../deps/ripemd-160/rmd160_64.c".}

  import bytes
  import arraylib

  proc MDinit(MDbuf: ptr array[5, uint32]) {.importc.}
  proc MDfinish(MDbuf: ptr array[5, uint32], strptr: ptr UncheckedArray[byte], lswlen: uint32, mswlen: uint32) {.importc.}

  proc ripemd160*(data: ptr UncheckedArray[byte], size: uint32): Hash160 {.inline.} =
    result = cast[Hash160](newArray[byte](20))
    MDinit(cast[ptr array[5, uint32]](result.data))
    MDfinish(cast[ptr array[5, uint32]](result.data), data, size, 0)

  template ripemd160*(data: Array[byte]): Hash160 =
    ripemd160(cast[ptr UncheckedArray[byte]](addr data[0]), data.len.uint32)

  template ripemd160*(data: string): Hash160 =
    ripemd160(cast[ptr UncheckedArray[byte]](addr data[0]), data.len.uint32)

  template ripemd160*(data: static string): Hash160 =
    var dataBytes = data.toBytes
    ripemd160(cast[ptr UncheckedArray[byte]](addr dataBytes[0]), dataBytes.len.uint32)

  proc ripemd160*(data: openArray[byte]): Hash160 =
    ripemd160(cast[ptr UncheckedArray[byte]](addr data[0]), data.len.uint32)

  template ripemd160*(data: static openArray[byte]): Hash160 =
    var dataBytes = data.toBytes
    ripemd160(cast[ptr UncheckedArray[byte]](addr dataBytes[0]), dataBytes.len.uint32)


  when isMainModule:
    echo ripemd160("test")

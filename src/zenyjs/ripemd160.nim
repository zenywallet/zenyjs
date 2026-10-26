# Copyright (c) 2025 zenywallet

when defined(js):
  import jsffi
  import jslib except Array
  import bytes
  import arraylib

  type
    Hash160* {.borrow: `.`.} = distinct Array[byte]

  var Ripemd160Mod = JsObject{}
  var Module: JsObject

  proc ripemd160_init*(module: JsObject) =
    Module = module
    Ripemd160Mod.ripemd160 = Module.cwrap("ripemd160", jsNull, [NumVar, NumVar])
    Ripemd160Mod.ripemd160hash = Module.cwrap("ripemd160hash", jsNull, [NumVar, NumVar])

  template init*(module: JsObject) = ripemd160_init(module)

  proc ripemd160*(data: Array[byte]): Hash160 =
    result = cast[Hash160](newArray[byte]())
    Ripemd160Mod.ripemd160(data.handle, result.handle)

  proc ripemd160hash*(data: Array[byte]): Hash160 =
    result = cast[Hash160](newArray[byte]())
    Ripemd160Mod.ripemd160hash(data.handle, result.handle)

  proc toBytes*(hash: Hash160): Array[byte] {.inline.} = cast[Array[byte]](hash)
  proc `$`*(data: Hash160): string = $data.toBytes


else:
  when defined(emscripten):
    const EXPORTED_FUNCTIONS* = ["_ripemd160", "_ripemd160hash"]

  import ripemd160_native
  import bytes
  import arraylib
  import utils

  proc ripemd160*(data: ptr UncheckedArray[byte], size: uint32): Hash160 {.inline.} =
    result = cast[Hash160](newArray[byte](20))
    MDinit(cast[ptr array[5, uint32]](result.data))
    MDfinish(cast[ptr array[5, uint32]](result.data), data, size, 0)

  template ripemd160*(data: Array[byte]): Hash160 =
    ripemd160(cast[ptr UncheckedArray[byte]](unsafeAddr data[0]), data.len.uint32)

  template ripemd160*(data: string): Hash160 =
    ripemd160(cast[ptr UncheckedArray[byte]](unsafeAddr data[0]), data.len.uint32)

  template ripemd160*(data: static string): Hash160 =
    var dataBytes = data.toBytes
    ripemd160(cast[ptr UncheckedArray[byte]](addr dataBytes[0]), dataBytes.len.uint32)

  proc ripemd160*(data: openArray[byte]): Hash160 =
    ripemd160(cast[ptr UncheckedArray[byte]](unsafeAddr data[0]), data.len.uint32)

  template ripemd160*(data: static openArray[byte]): Hash160 =
    var dataBytes = data.toBytes
    ripemd160(cast[ptr UncheckedArray[byte]](addr dataBytes[0]), dataBytes.len.uint32)

  template ripemd160hash*(pub: Array[byte]): Hash160 = ripemd160(sha256s(pub))

  proc ripemd160(data: Array[byte], result: var Hash160) {.exportc.} =
    result = ripemd160(cast[ptr UncheckedArray[byte]](unsafeAddr data[0]), data.len.uint32)

  proc ripemd160hash(pub: Array[byte], result: var Hash160) {.exportc.} =
    result = ripemd160(sha256s(pub))


  when isMainModule:
    echo ripemd160("test")

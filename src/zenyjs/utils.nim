# Copyright (c) 2020 zenywallet

when defined(js):
  import std/jsffi
  import jslib except Array
  import arraylib

  var Utils = JsObject{}
  var Module: JsObject

  proc init*(module: JsObject) =
    Module = module
    Utils.sha256d = Module.cwrap("sha256d", jsNull, [NumVar, NumVar])
    Utils.sha256s = Module.cwrap("sha256s", jsNull, [NumVar, NumVar])
    Utils.sha1Hmac = Module.cwrap("sha1Hmac", jsNull, [NumVar, NumVar, NumVar])
    Utils.sha256Hmac = Module.cwrap("sha256Hmac", jsNull, [NumVar, NumVar, NumVar])
    Utils.sha512Hmac = Module.cwrap("sha512Hmac", jsNull, [NumVar, NumVar, NumVar])

  proc sha256d*(data: Array[byte]): Uint8Array =
    withStack:
      var p = Module.stackAlloc(32)
      Utils.sha256d(data.handle, p)
      result = newUint8Array(Module.HEAPU8.buffer, p.to(cint), 32).slice().to(Uint8Array)

  proc sha256s*(data: Array[byte]): Uint8Array =
    withStack:
      var p = Module.stackAlloc(32)
      Utils.sha256s(data.handle, p)
      result = newUint8Array(Module.HEAPU8.buffer, p.to(cint), 32).slice().to(Uint8Array)

  proc sha1Hmac*(key, data: Array[byte]): Uint8Array =
    withStack:
      var p = Module.stackAlloc(20)
      Utils.sha1Hmac(key.handle, data.handle, p)
      result = newUint8Array(Module.HEAPU8.buffer, p.to(cint), 20).slice().to(Uint8Array)

  proc sha256Hmac*(key, data: Array[byte]): Uint8Array =
    withStack:
      var p = Module.stackAlloc(32)
      Utils.sha256Hmac(key.handle, data.handle, p)
      result = newUint8Array(Module.HEAPU8.buffer, p.to(cint), 32).slice().to(Uint8Array)

  proc sha512Hmac*(key, data: Array[byte]): Uint8Array =
    withStack:
      var p = Module.stackAlloc(64)
      Utils.sha512Hmac(key.handle, data.handle, p)
      result = newUint8Array(Module.HEAPU8.buffer, p.to(cint), 64).slice().to(Uint8Array)

else:
  when defined(emscripten):
    const EXPORTED_FUNCTIONS* = ["_sha256d", "_sha256s", "_sha1Hmac", "_sha256Hmac", "_sha512Hmac"]

  import json, strutils, br_hash
  import arraylib

  proc toJson*(val: uint64): JsonNode =
    if val > 9007199254740991'u64:
      newJString($val)
    else:
      newJInt(BiggestInt(val))

  proc toUint64*(val: JsonNode): uint64 =
    case val.kind
    of JString:
      result = val.getStr.parseBiggestUInt.uint64
    of JInt:
      result = val.getInt.uint64
    else:
      raiseAssert("toUint64 unexpected " & $val.kind)

  proc sha256d*(data: ptr UncheckedArray[byte], size: uint32): array[32, byte] {.inline.} =
    var h = sha256(data, size)
    sha256(cast[ptr UncheckedArray[byte]](addr h), h.len.uint32)

  proc sha256s*(data: ptr UncheckedArray[byte], size: uint32): array[32, byte] {.inline.} =
    sha256(data, size)

  proc sha256d*(data: openArray[byte]): array[32, byte] {.inline.} =
    var h = if data.len > 0:
      sha256(cast[ptr UncheckedArray[byte]](unsafeAddr data[0]), data.len.uint32)
    else:
      sha256(nil, 0.uint32)
    sha256(cast[ptr UncheckedArray[byte]](addr h), h.len.uint32)

  proc sha256s*(data: openArray[byte]): array[32, byte] {.inline.} =
    if data.len > 0:
      sha256(cast[ptr UncheckedArray[byte]](unsafeAddr data[0]), data.len.uint32)
    else:
      sha256(nil, 0.uint32)

  proc sha256d*(data: Array[byte]): array[32, byte] {.inline.} =
    var h = sha256(cast[ptr UncheckedArray[byte]](data.data), data.len.uint32)
    sha256(cast[ptr UncheckedArray[byte]](addr h), h.len.uint32)

  proc sha256s*(data: Array[byte]): array[32, byte] {.inline.} =
    sha256(cast[ptr UncheckedArray[byte]](data.data), data.len.uint32)

  proc sha256d*(data: Array[byte], ret: var array[32, byte]) {.exportc: "$1".} =
    var h = sha256(cast[ptr UncheckedArray[byte]](data.data), data.len.uint32)
    ret = sha256(cast[ptr UncheckedArray[byte]](addr h), h.len.uint32)

  proc sha256s*(data: Array[byte], ret: var array[32, byte]) {.exportc: "$1".} =
    ret = sha256(cast[ptr UncheckedArray[byte]](data.data), data.len.uint32)

  proc sha1Hmac*(key, data: Array[byte]): array[20, byte] {.inline.} =
    sha1Hmac(cast[ptr UncheckedArray[byte]](key.data), key.len.uint32,
            cast[ptr UncheckedArray[byte]](data.data), data.len.uint32)

  proc sha1Hmac*(key, data: Array[byte], ret: var array[20, byte]) {.exportc: "$1".} =
    ret = sha1Hmac(cast[ptr UncheckedArray[byte]](key.data), key.len.uint32,
                  cast[ptr UncheckedArray[byte]](data.data), data.len.uint32)

  proc sha256Hmac*(key, data: Array[byte]): array[32, byte] {.inline.} =
    sha256Hmac(cast[ptr UncheckedArray[byte]](key.data), key.len.uint32,
              cast[ptr UncheckedArray[byte]](data.data), data.len.uint32)

  proc sha256Hmac*(key, data: Array[byte], ret: var array[32, byte]) {.exportc: "$1".} =
    ret = sha256Hmac(cast[ptr UncheckedArray[byte]](key.data), key.len.uint32,
                    cast[ptr UncheckedArray[byte]](data.data), data.len.uint32)

  proc sha512Hmac*(key, data: Array[byte]): array[64, byte] {.inline.} =
    sha512Hmac(cast[ptr UncheckedArray[byte]](key.data), key.len.uint32,
              cast[ptr UncheckedArray[byte]](data.data), data.len.uint32)

  proc sha512Hmac*(key, data: Array[byte], ret: var array[64, byte]) {.exportc: "$1".} =
    ret = sha512Hmac(cast[ptr UncheckedArray[byte]](key.data), key.len.uint32,
                    cast[ptr UncheckedArray[byte]](data.data), data.len.uint32)

  proc sha1Hmac*(key, data: openArray[byte]): array[20, byte] {.inline.} =
    sha1Hmac(cast[ptr UncheckedArray[byte]](unsafeAddr key[0]), key.len.uint32,
            cast[ptr UncheckedArray[byte]](unsafeAddr data[0]), data.len.uint32)

  proc sha256Hmac*(key, data: openArray[byte]): array[32, byte] {.inline.} =
    sha256Hmac(cast[ptr UncheckedArray[byte]](unsafeAddr key[0]), key.len.uint32,
              cast[ptr UncheckedArray[byte]](unsafeAddr data[0]), data.len.uint32)

  proc sha512Hmac*(key, data: openArray[byte]): array[64, byte] {.inline.} =
    sha512Hmac(cast[ptr UncheckedArray[byte]](unsafeAddr key[0]), key.len.uint32,
              cast[ptr UncheckedArray[byte]](unsafeAddr data[0]), data.len.uint32)

  proc sha1Hmac*(key: string, data: openArray[byte]): array[20, byte] {.inline.} =
    sha1Hmac(cast[ptr UncheckedArray[byte]](unsafeAddr key[0]), key.len.uint32,
            cast[ptr UncheckedArray[byte]](unsafeAddr data[0]), data.len.uint32)

  proc sha256Hmac*(key: string, data: openArray[byte]): array[32, byte] {.inline.} =
    sha256Hmac(cast[ptr UncheckedArray[byte]](unsafeAddr key[0]), key.len.uint32,
              cast[ptr UncheckedArray[byte]](unsafeAddr data[0]), data.len.uint32)

  proc sha512Hmac*(key: string, data: openArray[byte]): array[64, byte] {.inline.} =
    sha512Hmac(cast[ptr UncheckedArray[byte]](unsafeAddr key[0]), key.len.uint32,
              cast[ptr UncheckedArray[byte]](unsafeAddr data[0]), data.len.uint32)

# Copyright (c) 2020 zenywallet

when defined(js):
  import std/jsffi
  import jslib except Array
  import arraylib

  type
    Hash20Array* = Uint8Array
    Hash32Array* = Uint8Array
    Hash64Array* = Uint8Array

  var Utils = JsObject{}
  var Module: JsObject

  proc init*(module: JsObject) =
    Module = module
    Utils.sha256d = Module.cwrap("sha256d", jsNull, [NumVar, NumVar])
    Utils.sha256s = Module.cwrap("sha256s", jsNull, [NumVar, NumVar])
    Utils.hmac_sha1 = Module.cwrap("hmac_sha1", jsNull, [NumVar, NumVar, NumVar])
    Utils.hmac_sha256 = Module.cwrap("hmac_sha256", jsNull, [NumVar, NumVar, NumVar])
    Utils.hmac_sha512 = Module.cwrap("hmac_sha512", jsNull, [NumVar, NumVar, NumVar])

  proc sha256d*(data: Array[byte]): Hash32Array =
    withStack:
      var p = Module.stackAlloc(32)
      Utils.sha256d(data.handle, p)
      result = newUint8Array(Module.HEAPU8.buffer, p.to(cint), 32).slice().to(Hash32Array)

  proc sha256s*(data: Array[byte]): Hash32Array =
    withStack:
      var p = Module.stackAlloc(32)
      Utils.sha256s(data.handle, p)
      result = newUint8Array(Module.HEAPU8.buffer, p.to(cint), 32).slice().to(Hash32Array)

  proc hmac_sha1*(key, data: Array[byte]): Hash20Array =
    withStack:
      var p = Module.stackAlloc(20)
      Utils.hmac_sha1(key.handle, data.handle, p)
      result = newUint8Array(Module.HEAPU8.buffer, p.to(cint), 20).slice().to(Hash20Array)

  proc hmac_sha256*(key, data: Array[byte]): Hash32Array =
    withStack:
      var p = Module.stackAlloc(32)
      Utils.hmac_sha256(key.handle, data.handle, p)
      result = newUint8Array(Module.HEAPU8.buffer, p.to(cint), 32).slice().to(Hash32Array)

  proc hmac_sha512*(key, data: Array[byte]): Hash64Array =
    withStack:
      var p = Module.stackAlloc(64)
      Utils.hmac_sha512(key.handle, data.handle, p)
      result = newUint8Array(Module.HEAPU8.buffer, p.to(cint), 64).slice().to(Hash64Array)

else:
  when defined(emscripten):
    const EXPORTED_FUNCTIONS* = ["_sha256d", "_sha256s", "_hmac_sha1", "_hmac_sha256", "_hmac_sha512"]

  import json, strutils, br_hash
  import arraylib

  type
    Hash20Array* = array[20, byte]
    Hash32Array* = array[32, byte]
    Hash64Array* = array[64, byte]

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

  proc sha256d*(data: ptr UncheckedArray[byte], size: uint32): Hash32Array {.inline.} =
    var h = sha256(data, size)
    sha256(cast[ptr UncheckedArray[byte]](addr h), h.len.uint32)

  proc sha256s*(data: ptr UncheckedArray[byte], size: uint32): Hash32Array {.inline.} =
    sha256(data, size)

  proc sha256d*(data: openArray[byte]): Hash32Array {.inline.} =
    var h = if data.len > 0:
      sha256(cast[ptr UncheckedArray[byte]](unsafeAddr data[0]), data.len.uint32)
    else:
      sha256(nil, 0.uint32)
    sha256(cast[ptr UncheckedArray[byte]](addr h), h.len.uint32)

  proc sha256s*(data: openArray[byte]): Hash32Array {.inline.} =
    if data.len > 0:
      sha256(cast[ptr UncheckedArray[byte]](unsafeAddr data[0]), data.len.uint32)
    else:
      sha256(nil, 0.uint32)

  proc sha256d*(data: Array[byte]): Hash32Array {.inline.} =
    var h = sha256(cast[ptr UncheckedArray[byte]](data.data), data.len.uint32)
    sha256(cast[ptr UncheckedArray[byte]](addr h), h.len.uint32)

  proc sha256s*(data: Array[byte]): Hash32Array {.inline.} =
    sha256(cast[ptr UncheckedArray[byte]](data.data), data.len.uint32)

  proc sha256d*(data: Array[byte], ret: var Hash32Array) {.exportc: "$1".} =
    var h = sha256(cast[ptr UncheckedArray[byte]](data.data), data.len.uint32)
    ret = sha256(cast[ptr UncheckedArray[byte]](addr h), h.len.uint32)

  proc sha256s*(data: Array[byte], ret: var Hash32Array) {.exportc: "$1".} =
    ret = sha256(cast[ptr UncheckedArray[byte]](data.data), data.len.uint32)

  proc hmac_sha1*(key, data: Array[byte]): Hash20Array {.inline.} =
    hmac_sha1(cast[ptr UncheckedArray[byte]](key.data), key.len.uint32,
              cast[ptr UncheckedArray[byte]](data.data), data.len.uint32)

  proc hmac_sha1*(key, data: Array[byte], ret: var Hash20Array) {.exportc: "$1".} =
    ret = hmac_sha1(cast[ptr UncheckedArray[byte]](key.data), key.len.uint32,
                    cast[ptr UncheckedArray[byte]](data.data), data.len.uint32)

  proc hmac_sha256*(key, data: Array[byte]): Hash32Array {.inline.} =
    hmac_sha256(cast[ptr UncheckedArray[byte]](key.data), key.len.uint32,
                cast[ptr UncheckedArray[byte]](data.data), data.len.uint32)

  proc hmac_sha256*(key, data: Array[byte], ret: var Hash32Array) {.exportc: "$1".} =
    ret = hmac_sha256(cast[ptr UncheckedArray[byte]](key.data), key.len.uint32,
                      cast[ptr UncheckedArray[byte]](data.data), data.len.uint32)

  proc hmac_sha512*(key, data: Array[byte]): Hash64Array {.inline.} =
    hmac_sha512(cast[ptr UncheckedArray[byte]](key.data), key.len.uint32,
                cast[ptr UncheckedArray[byte]](data.data), data.len.uint32)

  proc hmac_sha512*(key, data: Array[byte], ret: var Hash64Array) {.exportc: "$1".} =
    ret = hmac_sha512(cast[ptr UncheckedArray[byte]](key.data), key.len.uint32,
                      cast[ptr UncheckedArray[byte]](data.data), data.len.uint32)

  proc hmac_sha1*(key, data: openArray[byte]): Hash20Array {.inline.} =
    hmac_sha1(cast[ptr UncheckedArray[byte]](unsafeAddr key[0]), key.len.uint32,
              cast[ptr UncheckedArray[byte]](unsafeAddr data[0]), data.len.uint32)

  proc hmac_sha256*(key, data: openArray[byte]): Hash32Array {.inline.} =
    hmac_sha256(cast[ptr UncheckedArray[byte]](unsafeAddr key[0]), key.len.uint32,
                cast[ptr UncheckedArray[byte]](unsafeAddr data[0]), data.len.uint32)

  proc hmac_sha512*(key, data: openArray[byte]): Hash64Array {.inline.} =
    hmac_sha512(cast[ptr UncheckedArray[byte]](unsafeAddr key[0]), key.len.uint32,
              cast[ptr UncheckedArray[byte]](unsafeAddr data[0]), data.len.uint32)

  proc hmac_sha1*(key: string, data: openArray[byte]): Hash20Array {.inline.} =
    hmac_sha1(cast[ptr UncheckedArray[byte]](unsafeAddr key[0]), key.len.uint32,
              cast[ptr UncheckedArray[byte]](unsafeAddr data[0]), data.len.uint32)

  proc hmac_sha256*(key: string, data: openArray[byte]): Hash32Array {.inline.} =
    hmac_sha256(cast[ptr UncheckedArray[byte]](unsafeAddr key[0]), key.len.uint32,
                cast[ptr UncheckedArray[byte]](unsafeAddr data[0]), data.len.uint32)

  proc hmac_sha512*(key: string, data: openArray[byte]): Hash64Array {.inline.} =
    hmac_sha512(cast[ptr UncheckedArray[byte]](unsafeAddr key[0]), key.len.uint32,
                cast[ptr UncheckedArray[byte]](unsafeAddr data[0]), data.len.uint32)

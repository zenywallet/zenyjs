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

  proc sha512Hmac*(key, data: Array[byte]): Uint8Array =
    withStack:
      var p = Module.stackAlloc(64)
      Utils.sha512Hmac(key.handle, data.handle, p)
      result = newUint8Array(Module.HEAPU8.buffer, p.to(cint), 64).slice().to(Uint8Array)

else:
  when defined(emscripten):
    const EXPORTED_FUNCTIONS* = ["_sha256d", "_sha256s", "_sha512Hmac"]

  import json, strutils, nimcrypto
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

  proc sha256d*(data: openarray[byte]): array[32, byte] {.inline.} =
    sha256.digest(sha256.digest(data).data).data

  proc sha256s*(data: openarray[byte]): array[32, byte] {.inline.} =
    sha256.digest(data).data

  proc sha256d*(data: Array[byte]): array[32, byte] {.inline.} =
    sha256.digest(sha256.digest(cast[ptr byte](data.data), data.len.uint).data).data

  proc sha256s*(data: Array[byte]): array[32, byte] {.inline.} =
    sha256.digest(cast[ptr byte](data.data), data.len.uint).data

  proc sha256d*(data: Array[byte], ret: var array[32, byte]) {.exportc: "$1".} =
    ret = sha256.digest(sha256.digest(cast[ptr byte](data.data), data.len.uint).data).data

  proc sha256s*(data: Array[byte], ret: var array[32, byte]) {.exportc: "$1".} =
    ret = sha256.digest(cast[ptr byte](data.data), data.len.uint).data

  proc sha512Hmac*(key, data: Array[byte]): array[64, byte] {.inline.} =
    sha512.hmac(key.toSeq, data.toSeq).data

  proc sha512Hmac*(key, data: Array[byte], ret: var array[64, byte]) {.exportc: "$1".} =
    ret = sha512.hmac(key.toSeq, data.toSeq).data

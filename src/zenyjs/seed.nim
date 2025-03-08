# Copyright (c) 2022 zenywallet

type
  SeedError* = object of CatchableError

when defined(js):
  import jsffi
  import jslib except Array
  import arraylib

  var global {.importc, nodecl.}: JsObject

  proc isDefined[T](x: T): bool {.noSideEffect, importjs: "(typeof # !== 'undefined')".}

  proc cryptSeedUint8Array*(size: int): Uint8Array =
    try:
      if window.isDefined():
        if not window.crypto.isNil and not window.crypto.getRandomValues.isNil:
          var seedData = newUint8Array(size)
          window.crypto.getRandomValues(seedData)
          result = seedData
        else:
          raise newException(SeedError, "crypto.getRandomValues is not available")
      else:
        if global.cryptoMod.isNil:
          global.cryptoMod = require("crypto")
        var seedData = Uint8Array.from(global.cryptoMod.randomBytes(size)).to(Uint8Array)
        result = seedData
    except:
      raise newException(SeedError, getCurrentExceptionMsg())

  proc cryptSeed*(size: int): Array[byte] = cryptSeedUint8Array(size).toBytes

  when isMainModule:
    var seedData = cryptSeed(32)
    console.log(seedData)

else:
  import dotdot/seed_native
  import arraylib

  proc cryptSeed*(buf: ptr UncheckedArray[byte], size: cint): cint {.importc: "crypt_seed", cdecl.}

  proc cryptSeed*(buf: openArray[byte]): int {.inline.} =
    cryptSeed(cast[ptr UncheckedArray[byte]](buf), buf.len.cint)

  proc cryptSeed*(size: int): Array[byte] =
    var a = newArray[byte](size)
    var ret = cryptSeed(cast[ptr UncheckedArray[byte]](addr a[0]), size.cint)
    if ret == 0:
      result = a
    else:
      raise newException(SeedError, "seed generation failed")


  when isMainModule:
    var seedData = cryptSeed(32)
    echo seedData

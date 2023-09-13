# Copyright (c) 2023 zenywallet

when defined(js):
  import jsffi
  import jslib except Array
  import arraylib
  import eckey

  var RandomMod = JsObject{}
  var Module: JsObject

  proc init*(module: JsObject) =
    Module = module
    RandomMod.randomKey = Module.cwrap("random_key", jsNull, [NumVar])

  proc randomKey*(): tuple[prv: PrivateKey, pub: PublicKey] =
    withStack:
      var p = Module.stackAlloc(12 * 2)
      var zeroData = newUint8Array(12 * 2)
      Module.HEAPU8.set(zeroData, p)
      RandomMod.randomKey(p)
      var prv = newArray[byte]()
      var pub = newArray[byte]()
      Module.HEAPU8.set(newUint8Array(Module.HEAPU8.buffer, p.to(cint), 12), prv.handle)
      Module.HEAPU8.set(newUint8Array(Module.HEAPU8.buffer, p.to(cint) + 12, 12), pub.handle)
      result = (prv.PrivateKey, pub.PublicKey)

else:
  when defined(emscripten):
    const EXPORTED_FUNCTIONS* = ["_random_key"]

  import eckey
  import seed
  import custom

  proc randomKey*(): tuple[prv: PrivateKey, pub: PublicKey] =
    while true:
      try:
        let prv = cryptSeed(32).PrivateKey
        return (prv, prv.pub)
      except:
        let e = getCurrentException()
        echo e.name, ": ", e.msg

  proc randomKey(): tuple[prv: PrivateKey, pub: PublicKey] {.returnToLastParam, exportc: "random_key".}


  when isMainModule:
    import bytes
    import address

    var pair = randomKey()
    echo pair
    echo pair.pub.toAddress()

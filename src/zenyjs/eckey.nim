# Copyright (c) 2021 zenywallet

import arraylib

type
  PrivateKey* {.borrow: `.`.} = distinct Array[byte]
  PublicKey* {.borrow: `.`.} = distinct Array[byte]
  PublicKeyObj* {.borrow: `.`.} = distinct Array[byte]

  EcError* = object of CatchableError

when defined(js):
  import jsffi
  import jslib except Array

  template borrowArrayProc(typ: typedesc) =
    proc len*(x: typ): int {.borrow.}
    proc cap*(x: typ): int {.borrow.}
    proc data*(x: typ): int {.borrow.}
    proc toUint8Array*(x: typ): Uint8Array {.borrow.}
    proc toHex*(x: typ): cstring {.borrow.}

  borrowArrayProc(PrivateKey)
  borrowArrayProc(PublicKey)
  borrowArrayProc(PublicKeyObj)

  var EckeyMod = JsObject{}
  var Module: JsObject

  proc init*(module: JsObject) =
    Module = module
    EckeyMod.ecPubKeyCreate = Module.cwrap("eckey_ecPubKeyCreate", jsNull, [NumVar, NumVar])
    EckeyMod.ecPubKeySerializeCompressed = Module.cwrap("eckey_ecPubKeySerializeCompressed", jsNull, [NumVar, NumVar])
    EckeyMod.ecPubKeySerializeUncompressed = Module.cwrap("eckey_ecPubKeySerializeUncompressed", jsNull, [NumVar, NumVar])
    EckeyMod.pubUncompressed = Module.cwrap("eckey_pubUncompressed", jsNull, [NumVar, NumVar])
    EckeyMod.pub = Module.cwrap("eckey_pub", jsNull, [NumVar, NumVar])
    EckeyMod.pub_obj = Module.cwrap("eckey_pub_obj", jsNull, [NumVar, NumVar])
    EckeyMod.pubObj_prv = Module.cwrap("eckey_pubObj_prv", jsNull, [NumVar, NumVar])
    EckeyMod.pubObj_pub = Module.cwrap("eckey_pubObj_pub", jsNull, [NumVar, NumVar])
    EckeyMod.sign = Module.cwrap("eckey_sign", jsNull, [NumVar, NumVar, NumVar, NumVar])
    EckeyMod.verify_obj = Module.cwrap("eckey_verify_obj", NumVar, [NumVar, NumVar, NumVar])
    EckeyMod.verify = Module.cwrap("eckey_verify", NumVar, [NumVar, NumVar, NumVar])
    EckeyMod.tweakAdd_prv = Module.cwrap("eckey_tweakAdd_prv", jsNull, [NumVar, NumVar, NumVar])
    EckeyMod.tweakAdd_pubobj = Module.cwrap("eckey_tweakAdd_pubobj", jsNull, [NumVar, NumVar, NumVar])

  proc ecPubKeyCreate*(privateKey: PrivateKey): Uint8Array =
    withStack:
      var p = Module.stackAlloc(64)
      EckeyMod.ecPubKeyCreate(privateKey.handle, p)
      result = newUint8Array(Module.HEAPU8.buffer, p.to(cint), 64)

  proc ecPubKeySerializeCompressed*(pubkey: Uint8Array): Array[byte] =
    withStack:
      var p = Module.stackAlloc(64)
      Module.HEAPU8.set(pubkey, p)
      result = newArray[byte]()
      EckeyMod.ecPubKeySerializeCompressed(p, result.handle)

  proc ecPubKeySerializeUncompressed*(pubkey: Uint8Array): Array[byte] =
    withStack:
      var p = Module.stackAlloc(64)
      Module.HEAPU8.set(pubkey, p)
      result = newArray[byte]()
      EckeyMod.ecPubKeySerializeUncompressed(p, result.handle)

  proc pubUncompressed*(privateKey: PrivateKey): PublicKey =
    result = newArray[byte]().PublicKey
    EckeyMod.pubUncompressed(privateKey.handle, result.handle)

  proc pub*(privateKey: PrivateKey): PublicKey =
    result = newArray[byte]().PublicKey
    EckeyMod.pub(privateKey.handle, result.handle)

  proc pub*(publicKeyObj: PublicKeyObj): PublicKey =
    result = newArray[byte]().PublicKey
    EckeyMod.pub_obj(publicKeyObj.handle, result.handle)

  proc pubObj*(privateKey: PrivateKey): PublicKeyObj =
    result = newArray[byte]().PublicKeyObj
    EckeyMod.pubObj_prv(privateKey.handle, result.handle)

  proc pubObj*(publicKey: PublicKey): PublicKeyObj =
    result = newArray[byte]().PublicKeyObj
    EckeyMod.pubObj_pub(publicKey.handle, result.handle)

  proc sign*(privateKey: PrivateKey, hash32: Array[byte], grind: bool = true): Array[byte] =
    result = newArray[byte]()
    EckeyMod.sign(privateKey.handle, hash32.handle, grind, result.handle)

  proc verify*(publicKeyObj: PublicKeyObj, hash: Array[byte], der: Array[byte]): bool =
    (EckeyMod.verify_obj(publicKeyObj.handle, hash.handle, der.handle) > 0.toJs).to(bool)

  proc verify*(publicKey: PublicKey, hash: Array[byte], der: Array[byte]): bool =
    (EckeyMod.verify(publicKey.handle, hash.handle, der.handle) > 0.toJs).to(bool)

  proc tweakAdd*(privateKey: PrivateKey, tweak: Array[byte]): PrivateKey =
    result = newArray[byte]().PrivateKey
    EckeyMod.tweakAdd_prv(privateKey.handle, tweak.handle, result.handle)

  proc tweakAdd*(publicKeyObj: PublicKeyObj, tweak: Array[byte]): PublicKeyObj =
    result = newArray[byte]().PublicKeyObj
    EckeyMod.tweakAdd_pubobj(publicKeyObj.handle, tweak.handle, result.handle)

else:
  when defined(emscripten):
    const EXPORTED_FUNCTIONS* = ["_eckey_ecPubKeyCreate", "_eckey_ecPubKeySerializeCompressed",
      "_eckey_ecPubKeySerializeUncompressed", "_eckey_pubUncompressed",
      "_eckey_pub", "_eckey_pub_obj", "_eckey_pubObj_prv", "_eckey_pubObj_pub"
      , "_eckey_sign", "_eckey_verify_obj", "_eckey_verify",
      "_eckey_tweakAdd_prv", "_eckey_tweakAdd_pubobj"]

  import dotdot/secp256k1
  import custom

  converter toBytes*(o: PrivateKey | PublicKey | PublicKeyObj): Array[byte] {.inline.} =
    cast[Array[byte]](o)
  converter toPrivateKey*(s: Array[byte]): PrivateKey {.inline.} = PrivateKey(s)
  converter toPublicKey*(s: Array[byte]): PublicKey {.inline.} = PublicKey(s)
  converter toPublicKeyObj*(s: Array[byte]): PublicKeyObj {.inline.} = PublicKeyObj(s)
  converter toBytes*(o: secp256k1_pubkey): Array[byte] {.inline.} =
    (cast[array[64, byte]](o.data)).toArray
  converter toPublicKeyObj*(o: secp256k1_pubkey): PublicKeyObj {.inline.} =
    PublicKeyObj((cast[array[64, byte]](o.data)).toArray)
  converter toSecp256k1Pubkey*(o: PublicKeyObj): secp256k1_pubkey {.inline.} =
    cast[ptr secp256k1_pubkey](addr cast[ptr Array[byte]](unsafeAddr o)[][0])[]

  var secp256k1_ctx*: ptr secp256k1_context

  proc init*() {.inline.} =
    secp256k1_ctx = secp256k1_context_create(SECP256K1_CONTEXT_VERIFY or SECP256K1_CONTEXT_SIGN)

  proc free*() {.inline.} =
    secp256k1_context_destroy(secp256k1_ctx)
    secp256k1_ctx = nil

  proc ctx*(): ptr secp256k1_context =
    if secp256k1_ctx.isNil:
      init()
    result = secp256k1_ctx

  proc ecPubKeyCreate*(privateKey: PrivateKey): secp256k1_pubkey =
    if secp256k1_ec_pubkey_create(ctx(), addr result,
                                  cast[ptr uint8](addr cast[ptr Array[byte]](unsafeAddr privateKey)[][0])) == 0:
      raise newException(EcError, "Impressive! verify privateKey failed")

  proc ecPubKeyCreate*(privateKey: PrivateKey): secp256k1_pubkey {.returnToLastParam, exportc: "eckey_$1".}

  proc ecPubKeySerializeCompressed*(pubkey: secp256k1_pubkey): Array[byte] =
    var publicKey = newArray[byte](33)
    var outputlen = publicKey.len.csize_t
    if secp256k1_ec_pubkey_serialize(secp256k1_context_no_precomp, cast[ptr uint8](addr publicKey[0]),
                                    addr outputlen, unsafeAddr pubkey, SECP256K1_EC_COMPRESSED) == 0:
      raise newException(EcError, "ecp256k1_ec_pubkey_serialize")
    result = publicKey

  proc ecPubKeySerializeCompressed*(pubkey: secp256k1_pubkey): Array[byte] {.returnToLastParam, exportc: "eckey_$1".}

  proc ecPubKeySerializeUncompressed*(pubkey: secp256k1_pubkey): Array[byte] =
    var publicKey = newArray[byte](65)
    var outputlen = publicKey.len.csize_t
    if secp256k1_ec_pubkey_serialize(secp256k1_context_no_precomp, cast[ptr uint8](addr publicKey[0]),
                                    addr outputlen, unsafeAddr pubkey, SECP256K1_EC_UNCOMPRESSED) == 0:
      raise newException(EcError, "ecp256k1_ec_pubkey_serialize")
    result = publicKey

  proc ecPubKeySerializeUncompressed*(pubkey: secp256k1_pubkey): Array[byte] {.returnToLastParam, exportc: "eckey_$1".}

  proc pubUncompressed*(privateKey: PrivateKey): PublicKey =
    if privateKey.len != 32:
      raise newException(EcError, "pub privateKey len=" & $privateKey.len)
    var pubkey = ecPubKeyCreate(privateKey)
    result = ecPubKeySerializeUncompressed(pubkey)

  proc pubUncompressed*(privateKey: PrivateKey): PublicKey {.returnToLastParam, exportc: "eckey_$1".}

  proc pub*(privateKey: PrivateKey): PublicKey =
    if privateKey.len != 32:
      raise newException(EcError, "pub privateKey len=" & $privateKey.len)
    var pubkey = ecPubKeyCreate(privateKey)
    result = ecPubKeySerializeCompressed(pubkey)

  proc pub*(privateKey: PrivateKey): PublicKey {.returnToLastParam, exportc: "eckey_$1".}

  proc pub*(publicKeyObj: PublicKeyObj): PublicKey =
    if publicKeyObj.len != 64:
      raise newException(EcError, "pub publicKeyObj len=" & $publicKeyObj.len)
    result = ecPubKeySerializeCompressed(publicKeyObj)

  proc pub*(publicKeyObj: PublicKeyObj): PublicKey {.returnToLastParam, exportc: "eckey_$1_obj".}

  proc pubObj*(privateKey: PrivateKey): PublicKeyObj =
    if privateKey.len != 32:
      raise newException(EcError, "pubObj privateKey len=" & $privateKey.len)
    var pubkey = ecPubKeyCreate(privateKey)
    result = pubkey.toBytes

  proc pubObj*(privateKey: PrivateKey): PublicKeyObj {.returnToLastParam, exportc: "eckey_$1_prv".}

  proc pubObj*(publicKey: PublicKey): PublicKeyObj =
    var pubkey: secp256k1_pubkey
    let srcPub = cast[ptr uint8](addr cast[ptr Array[byte]](unsafeAddr publicKey)[][0])
    if secp256k1_ec_pubkey_parse(secp256k1_context_no_precomp, addr pubkey,
                                srcPub, publicKey.len.csize_t) == 0:
      raise newException(EcError, "secp256k1_ec_pubkey_parse")
    result = pubkey.toBytes

  proc pubObj*(publicKey: PublicKey): PublicKeyObj {.returnToLastParam, exportc: "eckey_$1_pub".}

  proc sign*(privateKey: PrivateKey, hash32: Array[byte], grind: bool = true): Array[byte] =
    var sig: secp256k1_ecdsa_signature
    let priv = cast[ptr uint8](addr cast[ptr Array[byte]](unsafeAddr privateKey)[][0])
    if secp256k1_ecdsa_sign(ctx(), addr sig, cast[ptr uint8](unsafeAddr hash32[0]), priv,
                            secp256k1_nonce_function_rfc6979, nil) != 1:
      raise newException(EcError, "secp256k1_ecdsa_sign")
    if grind and not cast[array[64, byte]](sig)[31] < 0x80.byte:
      var ndata = newArray[byte](32)
      var counter: uint32 = 1
      while true:
        copyMem(addr ndata[0], addr counter, sizeof(counter))
        if secp256k1_ecdsa_sign(ctx(), addr sig, cast[ptr uint8](unsafeAddr hash32[0]), priv,
                                secp256k1_nonce_function_rfc6979, addr ndata[0]) != 1:
          raise newException(EcError, "secp256k1_ecdsa_sign")
        if cast[array[64, byte]](sig)[31] < 0x80.byte:
          break
        inc(counter)
    var der = newArray[byte](75)
    var derLen = 75.csize_t
    if secp256k1_ecdsa_signature_serialize_der(ctx(), cast[ptr uint8](addr der[0]), addr derLen, addr sig) != 1:
      raise newException(EcError, "secp256k1_ecdsa_signature_serialize_der")
    result = der[0..<derLen]

  proc sign*(privateKey: PrivateKey, hash32: Array[byte], grind: bool = true): Array[byte] {.returnToLastParam, exportc: "eckey_$1".}

  proc verify*(publicKeyObj: PublicKeyObj, hash: Array[byte], der: Array[byte]): bool {.exportc: "eckey_$1_obj".} =
    var sig: secp256k1_ecdsa_signature
    var derLen = der.len.csize_t
    if secp256k1_ecdsa_signature_parse_der(ctx(), addr sig, cast[ptr uint8](unsafeAddr der[0]), derLen) != 1:
      return false
    secp256k1_ecdsa_signature_normalize(ctx(), addr sig, addr sig)
    let pubkey = cast[ptr secp256k1_pubkey](addr cast[ptr Array[byte]](unsafeAddr publicKeyObj)[][0])
    result = secp256k1_ecdsa_verify(ctx(), addr sig, cast[ptr uint8](unsafeAddr hash[0]), pubkey) == 1

  proc verify*(publicKey: PublicKey, hash: Array[byte], der: Array[byte]): bool {.exportc: "eckey_$1".} =
    publicKey.pubObj.verify(hash, der)

  proc tweakAdd*(privateKey: PrivateKey, tweak: Array[byte]): PrivateKey =
    if privateKey.len != 32 or tweak.len != 32:
      raise newException(EcError, "tweakAdd privateKey len=" & $privateKey.len & " tweak len=" & $tweak.len)
    var output: Array[byte] = privateKey
    if secp256k1_ec_privkey_tweak_add(ctx(), cast[ptr uint8](addr output[0]),
                                      cast[ptr uint8](unsafeAddr tweak[0])) == 0:
      raise newException(EcError, "secp256k1_ec_privkey_tweak_add")
    result = output

  proc tweakAdd*(privateKey: PrivateKey, tweak: Array[byte]): PrivateKey {.returnToLastParam, exportc: "eckey_$1_prv".}

  proc tweakAdd*(publicKeyObj: PublicKeyObj, tweak: Array[byte]): PublicKeyObj =
    if publicKeyObj.len != 64 or tweak.len != 32:
      raise newException(EcError, "tweakAdd publicKeyObj len=" & $publicKeyObj.len & " tweak len=" & $tweak.len)
    var output: Array[byte] = publicKeyObj
    if secp256k1_ec_pubkey_tweak_add(ctx(), cast[ptr secp256k1_pubkey](addr output[0]),
                                    cast[ptr uint8](unsafeAddr tweak[0])) == 0:
      raise newException(EcError, "secp256k1_ec_pubkey_tweak_add")
    result = output

  proc tweakAdd*(publicKeyObj: PublicKeyObj, tweak: Array[byte]): PublicKeyObj {.returnToLastParam, exportc: "eckey_$1_pubobj".}

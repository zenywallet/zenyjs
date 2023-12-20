# Copyright (c) 2021 zenywallet

type
  ALGO* = enum
    SHA1
    SHA256
    SHA512

  Totp* = ref object
    key*: string
    digit*: int
    timestep*: int
    algo*: ALGO

const DigitNum* = [uint32 1, 10, 100, 1000, 10000, 100000, 1000000, 10000000, 100000000]

proc newTotp*(key: string | seq[byte], digit: int = 6, timestep: int = 30, algo: ALGO = SHA1): Totp =
  result = new Totp
  result.key = cast[string](key)
  result.digit = digit
  result.timestep = timestep
  result.algo = algo

when defined(js):
  import std/json
  import std/jsffi
  import jslib except Array
  import jsuint64
  import arraylib
  import bytes

  var OtpMod = JsObject{}
  var Module: JsObject

  proc generateCounter*(totp: Totp, counter: Uint64): cstring =
    withStack:
      var ret = newArray[byte]()
      var totpKeyHex = Totp(key: totp.key.toHex, digit: totp.digit, timestep: totp.timestep, algo: totp.algo)
      var totpStringUint8Array = strToUint8Array(cstring($(%totpKeyHex)))
      var pTotp = Module.stackAlloc(totpStringUint8Array.length.to(int) + 1)
      Module.HEAPU8.set(totpStringUint8Array, pTotp)
      Module.HEAPU8[pTotp.to(int) + totpStringUint8Array.length.to(int)] = 0
      var pCuonter = Module.stackAlloc(8)
      Module.HEAPU8.set(counter.toUint8Array, pCuonter)
      discard OtpMod.generateCounter(pTotp, pCuonter, ret.handle)
      result = ret.toString()

  proc generateCounter*(totp: Totp, counter: uint64): cstring =
    generateCounter(totp, newUint64(counter))

  proc generate*(totp: Totp, sec: uint64): cstring =
    let tval = sec div totp.timestep.uint64
    result = generateCounter(totp, tval)

  proc init*(module: JsObject) =
    Module = module
    OtpMod.generateCounter = Module.cwrap("generateCounter", jsNull, [NumVar, NumVar, NumVar])

else:
  when defined(emscripten):
    const EXPORTED_FUNCTIONS* = ["_generateCounter"]

  import nimcrypto
  import endians
  import sequtils
  import strutils
  import arraylib
  import std/json
  import bytes

  proc toUint32BE(x: var byte): uint32 {.inline.} =
    bigEndian32(addr result, cast[ptr uint32](addr x))

  proc generateCounter*(totp: Totp, counter: uint64): string =
    var c = newSeq[byte](8)
    bigEndian64(addr c[0], unsafeAddr counter)
    var hash: seq[byte]
    case totp.algo
    of SHA1:
      hash = sha1.hmac(totp.key, c).data.toSeq
    of SHA256:
      hash = sha256.hmac(totp.key, c).data.toSeq
    of SHA512:
      hash = sha512.hmac(totp.key, c).data.toSeq
    let pos = hash[^1] and 0x0f'u8
    let code = hash[pos].toUint32BE and 0x7fffffff'u32
    let val = code mod DigitNum[totp.digit]
    result = align($val, totp.digit, '0')

  proc generateCounter*(totpString: cstring, counter: array[8, byte], retStringArray: var Array[byte]) {.exportc: "$1".} =
    var counter: uint64 = cast[ptr uint64](unsafeAddr counter)[]
    try:
      var totpJson = parseJson($totpString)
      var totp: Totp = totpJson.to(Totp)
      totp.key = totp.key.Hex.toBytes.toString
      retStringArray = totp.generateCounter(counter).toBytes
    except Exception as e:
      echo e.name, ": ", e.msg
      echo e.getStackTrace()
      raise

  proc generate*(totp: Totp, sec: uint64): string =
    let tval = sec div totp.timestep.uint64
    result = generateCounter(totp, tval)


  when isMainModule:
    # https://tools.ietf.org/html/rfc6238
    var totp_sha1 = newTotp("12345678901234567890", 8, 30, SHA1)
    var totp_sha256 = newTotp("12345678901234567890123456789012", 8, 30, SHA256)
    var totp_sha512 = newTotp("1234567890123456789012345678901234567890123456789012345678901234", 8, 30, SHA512)
    echo totp_sha1.generate(59)
    echo totp_sha256.generate(59)
    echo totp_sha512.generate(59)
    echo totp_sha1.generate(1111111109)
    echo totp_sha256.generate(1111111109)
    echo totp_sha512.generate(1111111109)
    echo totp_sha1.generate(1111111111)
    echo totp_sha256.generate(1111111111)
    echo totp_sha512.generate(1111111111)
    echo totp_sha1.generate(1234567890)
    echo totp_sha256.generate(1234567890)
    echo totp_sha512.generate(1234567890)
    echo totp_sha1.generate(2000000000)
    echo totp_sha256.generate(2000000000)
    echo totp_sha512.generate(2000000000)
    echo totp_sha1.generate(20000000000'u64)
    echo totp_sha256.generate(20000000000'u64)
    echo totp_sha512.generate(20000000000'u64)
    echo "-----"

    # google authenticator test
    import times, base32
    var t = newTotp(base32.dec("testtesttesttest")) # 6, 30, SHA1
    echo t.generate(epochTime().uint64)

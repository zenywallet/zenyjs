# Copyright (c) 2026 zenywallet

import std/strutils
import arraylib
import bytes

type
  Bip39Error* = object of CatchableError

when defined(js):
  import std/jsffi
  import jslib except Array

  type
    LangWords* = array[2048, cstring]

  var Bip39Mod = JsObject{}
  var Module: JsObject

  proc init*(module: JsObject) =
    Module = module
    Bip39Mod.entropyToWordIds = Module.cwrap("bip39_etoids", jsNull, [NumVar, NumVar])
    Bip39Mod.normalizeMnemonic = Module.cwrap("bip39_norm", jsNull, [NumVar, NumVar])
    Bip39Mod.pbkdf2 = Module.cwrap("bip39_pbkdf2", jsNull, [NumVar, NumVar, NumVar, NumVar])
    Bip39Mod.isNFKD = Module.cwrap("bip39_isnfdk", NumVar, [NumVar])
    Bip39Mod.wordIdsToEntropy = Module.cwrap("bip39_idstoe", NumVar, [NumVar, NumVar])
    Bip39Mod.toNFKC = Module.cwrap("bip39_tonfkc", jsNull, [NumVar, NumVar])

  proc entropyToWordIds*(entropy: Array[byte]): Array[uint] =
    result.newArray()
    discard Bip39Mod.entropyToWordIds(entropy.handle, result.handle)

  proc wordIdsToMnemonic*(wordIds: Array[uint], lang: LangWords): Array[string] =
    result.newArray(wordIds.len)
    for i, w in wordIds:
      result[i] = $lang[w]

  template entropyToMnemonic*(entropy: Array[byte], lang: untyped): Array[string] =
    entropy.entropyToWordIds().wordIdsToMnemonic(lang)

  proc normalizeMnemonic*(mnemonic: Array[string]): cstring =
    var ret = newArray[byte]()
    Bip39Mod.normalizeMnemonic(mnemonic.handle, ret.handle)
    ret.toString()

  proc plainMnemonic*(mnemonic: Array[string]): cstring = mnemonic.join(" ")

  proc stackString(strUint8Array: Uint8Array): cint =
    var slen = strUint8Array.length.to(int)
    var p = Module.stackAlloc(8 + 4 + slen).to(cint)
    let d = newDataView(Module.HEAPU8.buffer, p, 12)
    d.setUint32(0, slen, true)
    d.setUint32(4, p + 8, true)
    d.setUint32(8, slen, true)
    Module.HEAPU8.set(strUint8Array, p + 12)
    p

  proc stackString(s: cstring): cint =
    stackString(strToUint8Array(s))

  template stackString(s: string): cint = stackString(s.cstring)

  proc isNFKD(s: cstring): bool =
    withStack:
      var p = stackString(s)
      if Bip39Mod.isNFKD(p).to(cint) > 0: result = true

  proc mnemonicToSeed*(mnemonic: cstring, passphrase: cstring = ""): Array[byte] =
    if not mnemonic.isNFKD:
      raise newException(Bip39Error, "error: mnemonic is not NFKD")
    result.newArray()
    withStack:
      var m = stackString(mnemonic)
      var p = stackString(passphrase)
      var salt = stackString("mnemonic")
      discard Bip39Mod.pbkdf2(m, p, salt, result.handle)

  proc wordIdsToEntropy*(wordIds: Array[uint]): Array[byte] =
    result.newArray()
    var ret = Bip39Mod.wordIdsToEntropy(wordIds.handle, result.handle)
    if ret.to(cint) == 1:
      raise newException(Bip39Error, "error: empty word id list")
    elif ret.to(cint) == 2:
      raise newException(Bip39Error, "error: checksum invalid entropy")

  proc toNFKC(s: cstring): string =
    var ret = newArray[byte]()
    withStack:
      var p = stackString(s)
      Bip39Mod.toNFKC(p, ret.handle)
      result = $ret.toString()

  proc toNFKC(s: string): string = toNFKC(s.cstring)

  proc mnemonicToEntropy*(mnemonic: cstring, lang: LangWords): Array[byte] =
    var wordIds: Array[uint]
    for word in mnemonic.toNFKC.split(" "):
      block searchBlock:
        for i, w in lang:
          if word == w:
            wordIds.add(i.uint)
            break searchBlock
        raise newException(Bip39Error, "unknown words [" & word & "]")
    wordIdsToEntropy(wordIds)

  proc mnemonicToEntropy*(mnemonic: Array[string], lang: LangWords): Array[byte] =
    var wordIds: Array[uint]
    for word in mnemonic:
      var word = word.toNFKC
      block searchBlock:
        for i, w in lang:
          if word == w:
            wordIds.add(i.uint)
            break searchBlock
        raise newException(Bip39Error, "unknown words [" & word & "]")
    wordIdsToEntropy(wordIds)

else:
  import normalize
  import br_hash

  proc pbkdf2_bip39*(key: ptr UncheckedArray[byte], keySize: uint32,
                    pass: string = "", salt: string = "mnemonic"): Array[byte] =
    var hmacKeyCtx: br_hmac_key_context
    var hmacCtx: br_hmac_context
    var data: array[64, byte]
    var idx1 = [byte 0, 0, 0, 1]

    br_hmac_key_init(addr hmacKeyCtx, addr br_sha512_vtable, cast[pointer](key), keySize.csize_t)
    br_hmac_init(addr hmacCtx, addr hmacKeyCtx, 0)
    br_hmac_update(addr hmacCtx, cast[pointer](addr salt[0]), salt.len.csize_t)
    if pass.len > 0:
      br_hmac_update(addr hmacCtx, cast[pointer](addr pass[0]), pass.len.csize_t)
    br_hmac_update(addr hmacCtx, cast[pointer](addr idx1[0]), idx1.len.csize_t)
    discard br_hmac_out(addr hmacCtx, addr data)
    result = data.toBytes
    for i in 2..2048:
      br_hmac_init(addr hmacCtx, addr hmacKeyCtx, 0)
      br_hmac_update(addr hmacCtx, cast[pointer](addr data), 64.csize_t)
      discard br_hmac_out(addr hmacCtx, addr data)
      for k in 0..<64:
        result[k] = result[k] xor data[k]
    zeroMem(addr data, sizeof(data))
    zeroMem(addr hmacCtx, sizeof(br_hmac_context))
    zeroMem(addr hmacKeyCtx, sizeof(br_hmac_key_context))

  proc entropyToWordIds*(entropy: Array[byte]): Array[uint] =
    result.newArray(1)
    var bitIn = 8
    var bitOut = 11
    for i, d in entropy:
      var d = d.uint
      if bitOut > bitIn:
        bitOut = bitOut - bitIn
        result[^1] = result[^1] or ((d and (1.uint shl bitIn - 1)) shl bitOut)
      else:
        bitIn = bitIn - bitOut
        bitOut = 11 - bitIn
        result[^1] = result[^1] or (d shr bitIn)
        result.add((d and (1.uint shl bitIn - 1)) shl bitOut)
        bitIn = 8
    var sha256hash = sha256(cast[ptr UncheckedArray[byte]](addr entropy[0]), entropy.len.uint32).toBytes
    var checkSumLen = 11 - entropy.len * 8 mod 11
    var checkSum = sha256hash[0].uint shr (8 - checkSumLen)
    result[^1] = result[^1] or checkSum

  template wordIdsToMnemonic*(wordIds: Array[uint], lang: untyped): Array[string] =
    var ret: Array[string]
    for w in wordIds:
      ret.add lang[w]
    ret

  template entropyToMnemonic*(entropy: Array[byte], lang: untyped): Array[string] =
    entropy.entropyToWordIds().wordIdsToMnemonic(lang)

  proc normalizeMnemonic*(mnemonic: Array[string]): string = mnemonic.join(" ").toNFKD()

  proc plainMnemonic*(mnemonic: Array[string]): string = mnemonic.join(" ") # NFC NFKC

  proc mnemonicToSeed*(mnemonic: string, passphrase: string = ""): Array[byte] =
    if not mnemonic.isNFKD:
      raise newException(Bip39Error, "error: mnemonic is not NFKD")
    pbkdf2_bip39(cast[ptr UncheckedArray[byte]](addr mnemonic[0]), mnemonic.len.uint32, passphrase)

  proc wordIdsToEntropy*(wordIds: Array[uint]): Array[byte] =
    if wordIds.len > 0:
      result.add(0)
    else:
      raise newException(Bip39Error, "error: empty word id list")
    var pos = 0

    for i, w in wordIds:
      pos = (11 * i) mod 8 + 3
      result[^1] = result[^1] or (w shr pos).uint8
      if pos >= 8:
        result.add(((w and (1.uint shl pos - 1)) shr (pos - 8)).uint8)
        result.add(((w and (1.uint shl (pos - 8) - 1)) shl (16 - pos)).uint8)
      else:
        result.add(((w and (1.uint shl pos - 1)) shl (8 - pos)).uint8)
    if pos == 8:
      result.setLen(result.len - 1)

    var entropyLen = result.len - 1
    var checkSumLen = wordIds.len * 11 mod 8
    if checkSumLen == 0: checkSumLen = 8
    var checkSum = result[^1].uint shr (8 - checkSumLen)
    result.setLen(entropyLen)
    var sha256hash = sha256(cast[ptr UncheckedArray[byte]](addr result[0]), result.len.uint32).toBytes
    var sha256CheckSum = sha256hash[0].uint shr (8 - checkSumLen)
    if checkSum != sha256CheckSum:
      raise newException(Bip39Error, "error: checksum invalid entropy")

  template mnemonicToEntropy*(mnemonic: string, lang: untyped): Array[byte] =
    var wordIds: Array[uint]
    for word in mnemonic.toNFKC.split(" "):
      block searchBlock:
        for i, w in lang:
          if word == w:
            wordIds.add(i.uint)
            break searchBlock
        raise newException(Bip39Error, "unknown words [" & word & "]")
    wordIdsToEntropy(wordIds)

  template mnemonicToEntropy*(mnemonic: Array[string], lang: untyped): Array[byte] =
    var wordIds: Array[uint]
    for word in mnemonic:
      var word = word.toNFKC
      block searchBlock:
        for i, w in lang:
          if word == w:
            wordIds.add(i.uint)
            break searchBlock
        raise newException(Bip39Error, "unknown words [" & word & "]")
    wordIdsToEntropy(wordIds)

  when defined(emscripten):
    const EXPORTED_FUNCTIONS* = ["_bip39_etoids", "_bip39_norm", "_bip39_pbkdf2", "_bip39_isnfdk",
      "_bip39_idstoe", "_bip39_tonfkc"]

    proc entropyToWordIds(entropy: var Array[byte], result: var Array[uint]) {.exportc: "bip39_etoids".} =
      result = entropyToWordIds(entropy)

    proc normalizeMnemonic(mnemonic: var Array[string], result: var Array[byte]) {.exportc: "bip39_norm".} =
      result = mnemonic.join(" ").toNFKD().toBytes

    proc bip39_pbkdf2(key: string, pass: string, salt: string, result: var Array[byte]) {.exportc.} =
      result = pbkdf2_bip39(cast[ptr UncheckedArray[byte]](addr key[0]), key.len.uint32, pass, salt)

    proc bip39_isnfdk(s: string): bool {.exportc.} = s.isNFKD

    proc wordIdsToEntropy2(wordIds: Array[uint]): tuple[ret: Array[byte], err: int] =
      if wordIds.len > 0:
        result.ret.add(0)
      else:
        result.err = 1
        return
      var pos = 0

      for i, w in wordIds:
        pos = (11 * i) mod 8 + 3
        result.ret[^1] = result.ret[^1] or (w shr pos).uint8
        if pos >= 8:
          result.ret.add(((w and (1.uint shl pos - 1)) shr (pos - 8)).uint8)
          result.ret.add(((w and (1.uint shl (pos - 8) - 1)) shl (16 - pos)).uint8)
        else:
          result.ret.add(((w and (1.uint shl pos - 1)) shl (8 - pos)).uint8)
      if pos == 8:
        result.ret.setLen(result.ret.len - 1)

      var entropyLen = result.ret.len - 1
      var checkSumLen = wordIds.len * 11 mod 8
      if checkSumLen == 0: checkSumLen = 8
      var checkSum = result.ret[^1].uint shr (8 - checkSumLen)
      result.ret.setLen(entropyLen)
      var sha256hash = sha256(cast[ptr UncheckedArray[byte]](addr result.ret[0]), result.ret.len.uint32).toBytes
      var sha256CheckSum = sha256hash[0].uint shr (8 - checkSumLen)
      if checkSum != sha256CheckSum:
        result.err = 2
        return

    proc wordIdsToEntropy*(wordIds: var Array[uint], ret: var Array[byte]): int {.exportc: "bip39_idstoe".} =
      (ret, result) = wordIdsToEntropy2(wordIds)

    proc bip39_tonfkc(s: string, result: var Array[byte]) {.exportc.} =
      result = s.toNFKC().toBytes


when isMainModule:
  import zenyjs
  import seed
  import bip39_en
  import bip39_ja

  const en = bip39_en.words
  const ja = bip39_ja.words

  zenyjs.ready:
    var entropyLenList = [4, 8, 12, 16, 20, 24, 28, 32]
    var wordLenList = [3, 6, 9, 12, 15, 18, 21, 24]

    for lang in [en, ja]:
      for i, entropyLen in entropyLenList:
        var entropy = cryptSeed(entropyLen)
        var mnemonic = entropyToMnemonic(entropy, lang)
        var bip39Seed = mnemonicToSeed(normalizeMnemonic(mnemonic))
        echo "entropy: ", entropy
        echo "mnemonic: ", plainMnemonic(mnemonic)
        echo "bip39 seed: ", bip39Seed

        var entropy2 = mnemonicToEntropy(mnemonic, lang)
        assert entropy == entropy2
        assert mnemonic.len == wordLenList[i]
        assert plainMnemonic(mnemonic) == normalizeMnemonic(mnemonic).toNFKC()

        var wordIds = entropyToWordIds(entropy)
        var mnemonic2 = wordIdsToMnemonic(wordIds, lang)
        assert wordIds.len == wordLenList[i]
        assert mnemonic == mnemonic2

# Copyright (c) 2021 zenywallet

type
  VersionPrefix* = enum
    tprv = 0x04358394'u32 #bip32
    tpub = 0x043587cf'u32 #bip32
    vprv = 0x045f18bc'u32 #bip84
    vpub = 0x045f1cf6'u32 #bip84
    xprv = 0x0488ade4'u32 #bip32
    xpub = 0x0488b21e'u32 #bip32
    zprv = 0x04b2430c'u32 #bip84
    zpub = 0x04b24746'u32 #bip84

when defined(js):
  import std/jsffi
  import jslib except Array
  import arraylib
  import address

  type
    HDNode* = object
      handle*: JsObject

    HdError* = object of CatchableError

  var Bip32Mod = JsObject{}
  var Module: JsObject

  proc init*(module: JsObject) =
    Module = module
    Bip32Mod.free = Module.cwrap("bip32_free", jsNull, [NumVar])
    Bip32Mod.duplicate = Module.cwrap("bip32_duplicate", NumVar, [NumVar])
    Bip32Mod.master = Module.cwrap("bip32_master", NumVar, [NumVar, NumVar, NumVar])
    Bip32Mod.masterBuf = Module.cwrap("bip32_master_buf", NumVar, [NumVar, NumVar, NumVar, NumVar])
    Bip32Mod.xprv = Module.cwrap("bip32_xprv_c", NumVar, [NumVar])
    Bip32Mod.xpub = Module.cwrap("bip32_xpub_c", NumVar, [NumVar])
    Bip32Mod.node = Module.cwrap("bip32_node", NumVar, [NumVar])
    Bip32Mod.hardened = Module.cwrap("bip32_hardened", NumVar, [NumVar, NumVar])
    Bip32Mod.derive = Module.cwrap("bip32_derive", NumVar, [NumVar, NumVar])
    Bip32Mod.address = Module.cwrap("bip32_address", NumVar, [NumVar, NumVar])
    Bip32Mod.segwitAddress = Module.cwrap("bip32_segwitAddress", NumVar, [NumVar, NumVar])
    Bip32Mod.xprvEx = Module.cwrap("bip32_xprv_c_ex", NumVar, [NumVar, NumVar])
    Bip32Mod.xpubEx = Module.cwrap("bip32_xpub_c_ex", NumVar, [NumVar, NumVar])
    Bip32Mod.addressEx = Module.cwrap("bip32_address_ex", NumVar, [NumVar, NumVar, NumVar])
    Bip32Mod.segwitAddressEx = Module.cwrap("bip32_segwitAddress_ex", NumVar, [NumVar, NumVar, NumVar])

  proc duplicate(handle: JsObject): JsObject =
    result = Bip32Mod.duplicate(handle)
    return result

  proc `=destroy`*(node: var HDNode) =
    if not node.handle.isNil:
      Bip32Mod.free(node.handle)
      node.handle = jsNull

  proc `=copy`*(a: var HDNode; b: HDNode) =
    `=destroy`(a)
    if not b.handle.isNil:
      a.handle = b.handle.duplicate()

  proc `=sink`*(a: var HDNode; b: HDNode) =
    `=destroy`(a)
    if not b.handle.isNil:
      a.handle = b.handle

  proc master*(seed: Array[byte], versionPrv: VersionPrefix = xprv,
              versionPub: VersionPrefix = xpub): HDNode =
    result.handle = Bip32Mod.master(seed.handle, versionPrv, versionPub)

  proc master*(seed: Uint8Array, versionPrv: VersionPrefix = xprv,
              versionPub: VersionPrefix = xpub): HDNode =
    var pdata = Module.malloc(seed.length.to(int))
    Module.HEAPU8.set(seed, pdata)
    result.handle = Bip32Mod.masterBuf(pdata, seed.length.to(int), versionPrv, versionPub)
    Module.free(pdata)
    return result

  proc xprv*(node: HDNode): cstring =
    var p = Bip32Mod.xprv(node.handle)
    if p.to(int) == 0:
      raise newException(HdError, "xprv privateKey len=0")
    var a = newUint8Array(Module.HEAPU8.buffer, p.to(int), 256)
    var s = a.slice(0, a.indexOf(0)).uint8ArrayToStr()
    return s

  proc xpub*(node: HDNode): cstring =
    var p = Bip32Mod.xpub(node.handle)
    if p.to(int) == 0:
      raise newException(HdError, "xprv privateKey len=0")
    var a = newUint8Array(Module.HEAPU8.buffer, p.to(int), 256)
    var s = a.slice(0, a.indexOf(0)).uint8ArrayToStr()
    return s

  proc xprvEx*(node: HDNode): cstring =
    var p = Module.malloc(4)
    var size = Bip32Mod.xprvEx(node.handle, p)
    if size.to(int) == 0:
      raise newException(HdError, "xprv privateKey len=0")
    var outBuf = newUint32Array(Module.HEAPU32.buffer, p.to(int), 1)[0]
    var a = newUint8Array(Module.HEAPU8.buffer, outBuf.to(int), size.to(int)).slice()
    var s = a.uint8ArrayToStr()
    return s

  proc xpubEx*(node: HDNode): cstring =
    var p = Module.malloc(4)
    var size = Bip32Mod.xpubEx(node.handle, p)
    var outBuf = newUint32Array(Module.HEAPU32.buffer, p.to(int), 1)[0]
    var a = newUint8Array(Module.HEAPU8.buffer, outBuf.to(int), size.to(int)).slice()
    var s = a.uint8ArrayToStr()
    return s

  proc node*(x: cstring): HDNode =
    var a = strToUint8Array(x)
    var size = a.length.to(cint) + 1
    var zeroData = newUint8Array(size)
    var p = Module.malloc(size)
    Module.HEAPU8.set(zeroData, p)
    Module.HEAPU8.set(a, p)
    result.handle = Bip32Mod.node(p)
    if result.handle.to(int) == 0:
      raise newException(HdError, "node unknown error")

  proc hardened*(node: HDNode, index: uint32): HDNode =
    result.handle = Bip32Mod.hardened(node.handle, index)
    if result.handle.to(int) == 0:
      raise newException(HdError, "derive privateKey len=0")

  proc derive*(node: HDNode, index: uint32): HDNode =
    result.handle = Bip32Mod.derive(node.handle, index)

  proc getAddress*(networkId: NetworkId, node: HDNode): cstring =
    var p = Bip32Mod.address(node.handle, networkId.int)
    var a = newUint8Array(Module.HEAPU8.buffer, p.to(int), 256)
    var s = a.slice(0, a.indexOf(0)).uint8ArrayToStr()
    return s

  proc getSegwitAddress*(networkId: NetworkId, node: HDNode): cstring =
    var p = Bip32Mod.segwitAddress(node.handle, networkId.int)
    var a = newUint8Array(Module.HEAPU8.buffer, p.to(int), 256)
    var s = a.slice(0, a.indexOf(0)).uint8ArrayToStr()
    return s

  proc address*(node: HDNode, networkId: NetworkId = 0.NetworkId): cstring =
    var p = Bip32Mod.address(node.handle, networkId.int)
    var a = newUint8Array(Module.HEAPU8.buffer, p.to(int), 256)
    var s = a.slice(0, a.indexOf(0)).uint8ArrayToStr()
    return s

  proc segwitAddress*(node: HDNode, networkId: NetworkId = 0.NetworkId): cstring =
    var p = Bip32Mod.segwitAddress(node.handle, networkId.int)
    var a = newUint8Array(Module.HEAPU8.buffer, p.to(int), 256)
    var s = a.slice(0, a.indexOf(0)).uint8ArrayToStr()
    return s

  proc addressEx*(node: HDNode, networkId: NetworkId = 0.NetworkId): cstring =
    var p = Module.malloc(4)
    var size = Bip32Mod.addressEx(node.handle, networkId.int, p)
    var outBuf = newUint32Array(Module.HEAPU32.buffer, p.to(int), 1)[0]
    var a = newUint8Array(Module.HEAPU8.buffer, outBuf.to(int), size.to(int)).slice()
    var s = a.uint8ArrayToStr()
    return s

  proc segwitAddressEx*(node: HDNode, networkId: NetworkId = 0.NetworkId): cstring =
    var p = Module.malloc(4)
    var size = Bip32Mod.segwitAddressEx(node.handle, networkId.int, p)
    var outBuf = newUint32Array(Module.HEAPU32.buffer, p.to(int), 1)[0]
    var a = newUint8Array(Module.HEAPU8.buffer, outBuf.to(int), size.to(int)).slice()
    var s = a.uint8ArrayToStr()
    return s

else:
  when defined(emscripten):
    const EXPORTED_FUNCTIONS* = ["_bip32_free", "_bip32_master", "_bip32_master_buf",
                                "_bip32_xprv_c", "_bip32_xpub_c", "_bip32_node",
                                "_bip32_hardened", "_bip32_derive", "_bip32_address", "_bip32_segwitAddress",
                                "_bip32_duplicate", "_bip32_xprv_c_ex", "_bip32_xpub_c_ex",
                                "_bip32_address_ex", "_bip32_segwitAddress_ex"]

  import std/sequtils
  import nimcrypto
  import arraylib
  import bytes
  import base58
  import eckey
  import utils
  import address

  type
    ChainCode* = distinct Array[byte]

    HDNodeObj = object
      depth*: uint8
      fingerprint*: uint32
      childNumber*: uint32
      chainCode*: ChainCode
      privateKey*: PrivateKey
      publicKey*: PublicKey
      versionPrv: VersionPrefix
      versionPub: VersionPrefix
      xprv: cstring
      xpub: cstring
      address: cstring
      segwitAddress: cstring

    HDNode* = ptr HDNodeObj


  const HdErrorExceptionDisabled = defined(emscripten)

  when not HdErrorExceptionDisabled:
    type
      HdError* = object of CatchableError

  converter toBytes*(o: ChainCode): Array[byte] = cast[Array[byte]](o)
  converter toChainCode*(s: Array[byte]): ChainCode {.inline.} = ChainCode(s)

  proc free*(node: HDNode) {.exportc: "bip32_$1".} =
    if not node.segwitAddress.isNil:
      node.segwitAddress.deallocShared()
    if not node.address.isNil:
      node.address.deallocShared()
    if not node.xpub.isNil:
      node.xpub.deallocShared()
    if not node.xprv.isNil:
      node.xprv.deallocShared()
    `=destroy`(node.publicKey)
    `=destroy`(node.privateKey)
    `=destroy`(node.chainCode)
    node.deallocShared()

  proc duplicate*(node: HDNode): HDNode {.exportc: "bip32_$1".} =
    result = cast[HDNode](allocShared0(sizeof(HDNodeObj)))
    result.depth = node.depth
    result.fingerprint = node.fingerprint
    result.childNumber = node.childNumber
    result.chainCode = node.chainCode
    result.privateKey = node.privateKey
    result.publicKey = node.publicKey
    result.versionPrv = node.versionPrv
    result.versionPub = node.versionPub

  proc master*(seed: Array[byte], versionPrv: VersionPrefix = xprv,
              versionPub: VersionPrefix = xpub): HDNode {.exportc: "bip32_$1".} =
    result = cast[HDNode](allocShared0(sizeof(HDNodeObj)))
    var I = sha512.hmac("Bitcoin seed", seed.toSeq).data.toBytes
    result.depth = 0
    result.fingerprint = 0
    result.childNumber = 0
    result.chainCode = I[32..63]
    result.privateKey = I[0..31]
    result.publicKey = result.privateKey.pub
    result.versionPrv = versionPrv
    result.versionPub = versionPub

  proc master*(seedBuf: ptr UncheckedArray[byte], seedSize: int, versionPrv: VersionPrefix = xprv,
              versionPub: VersionPrefix = xpub): HDNode {.exportc: "bip32_$1_buf".} =
    var seed = seedBuf.toBytes(seedSize)
    result = master(seed, versionPrv, versionPub)

  proc addCheck*(data: Array[byte]): Array[byte] = concat(data.toSeq, sha256d(data)[0..3]).toBytes

  proc check(data: Array[byte]): bool =
    var chk = data[^4..^1]
    if chk == sha256d(data[0..^5])[0..3].toArray:
      return true
    return false

  proc xprv*(node: HDNode): string =
    if node.privateKey.len != 32:
      when HdErrorExceptionDisabled:
        return
      else:
        raise newException(HdError, "xprv privateKey len=" & $node.privateKey.len)
    var d = (node.versionPrv, node.depth, node.fingerprint, node.childNumber,
            node.chainCode, 0x00'u8, node.privateKey).toBytesBE.addCheck
    result = base58.enc(d)

  proc xpub*(node: HDNode): string =
    var d = (node.versionPub, node.depth, node.fingerprint, node.childNumber,
            node.chainCode, node.publicKey).toBytesBE.addCheck
    result = base58.enc(d)

  proc set(p: var cstring, s: string): cstring {.discardable.} =
    if not p.isNil:
      p.deallocShared()
    var len = s.len
    p = cast[cstring](allocShared0(len + 1))
    copyMem(p, unsafeAddr s[0], len)
    result = p

  proc xprv_c(node: HDNode): cstring {.exportc: "bip32_$1".} =
    if node.privateKey.len != 32:
      when HdErrorExceptionDisabled:
        return
      else:
        raise newException(HdError, "xprv privateKey len=" & $node.privateKey.len)
    var d = (node.versionPrv, node.depth, node.fingerprint, node.childNumber,
            node.chainCode, 0x00'u8, node.privateKey).toBytesBE.addCheck
    var s = base58.enc(d)
    node.xprv.set(s)

  proc xpub_c(node: HDNode): cstring {.exportc: "bip32_$1".} =
    var d = (node.versionPub, node.depth, node.fingerprint, node.childNumber,
            node.chainCode, node.publicKey).toBytesBE.addCheck
    var s = base58.enc(d)
    node.xpub.set(s)

  proc xprv_c(node: HDNode, xprv: ptr cstring): cint {.exportc: "bip32_$1_ex".} =
    if node.privateKey.len != 32:
      when HdErrorExceptionDisabled:
        return
      else:
        raise newException(HdError, "xprv privateKey len=" & $node.privateKey.len)
    var d = (node.versionPrv, node.depth, node.fingerprint, node.childNumber,
            node.chainCode, 0x00'u8, node.privateKey).toBytesBE.addCheck
    var s = base58.enc(d)
    node.xprv.set(s)
    xprv[] = node.xprv
    result = s.len.cint

  proc xpub_c(node: HDNode, xpub: ptr cstring): cint {.exportc: "bip32_$1_ex".} =
    var d = (node.versionPub, node.depth, node.fingerprint, node.childNumber,
            node.chainCode, node.publicKey).toBytesBE.addCheck
    var s = base58.enc(d)
    node.xpub.set(s)
    xpub[] = node.xpub
    result = s.len.cint

  proc node*(x: cstring): HDNode {.exportc: "bip32_$1".} =
    var d = base58.dec(toString(cast[ptr UncheckedArray[byte]](x), x.len))
    if not check(d):
      when HdErrorExceptionDisabled:
        return
      else:
        raise newException(HdError, "invalid serialization format")
    var node = cast[HDNode](allocShared0(sizeof(HDNodeObj)))
    node.depth = d[4]
    when defined(emscripten):
      node.fingerprint = d[5..8].toUint32BE
      node.childNumber = d[9..12].toUint32BE
    else: # wasm SAFE_HEAP=1 alignfault
      node.fingerprint = d[5].toUint32BE
      node.childNumber = d[9].toUint32BE
    node.chainCode = d[13..44]
    var ver = d.toUint32BE
    case ver
    of VersionPrefix.xprv.uint32:
      node.privateKey = d[46..77]
      node.publicKey = node.privateKey.pub
      node.versionPrv = VersionPrefix.xprv
      node.versionPub = VersionPrefix.xpub
    of VersionPrefix.xpub.uint32:
      node.publicKey = d[45..77]
      node.versionPub = VersionPrefix.xpub
    of VersionPrefix.zprv.uint32:
      node.privateKey = d[46..77]
      node.publicKey = node.privateKey.pub
      node.versionPrv = VersionPrefix.zprv
      node.versionPub = VersionPrefix.zpub
    of VersionPrefix.zpub.uint32:
      node.publicKey = d[45..77]
      node.versionPub = VersionPrefix.zpub
    of VersionPrefix.tprv.uint32:
      node.privateKey = d[46..77]
      node.publicKey = node.privateKey.pub
      node.versionPrv = VersionPrefix.tprv
      node.versionPub = VersionPrefix.tpub
    of VersionPrefix.tpub.uint32:
      node.publicKey = d[45..77]
      node.versionPub = VersionPrefix.tpub
    of VersionPrefix.vprv.uint32:
      node.privateKey = d[46..77]
      node.publicKey = node.privateKey.pub
      node.versionPrv = VersionPrefix.vprv
      node.versionPub = VersionPrefix.vpub
    of VersionPrefix.vpub.uint32:
      node.publicKey = d[45..77]
      node.versionPub = VersionPrefix.vpub
    else:
      when HdErrorExceptionDisabled:
        return
      else:
        raise newException(HdError, "unknown version " & $ver.toBytes)
    result = node

  proc node*(x: string): HDNode = node(x.cstring)

  proc hardened*(node: HDNode, index: uint32): HDNode {.exportc: "bip32_$1".} =
    if node.privateKey.len != 32:
      when HdErrorExceptionDisabled:
        return
      else:
        raise newException(HdError, "derive privateKey len=" & $node.privateKey.len)
    var childNumber = (0x80000000'u32 or index)
    var data = (0x00'u8, node.privateKey, childNumber).toBytesBE
    var I = sha512.hmac(node.chainCode.toSeq, data.toSeq).data.toBytes
    var privateKey: PrivateKey = I[0..31]
    var chainCode: ChainCode = I[32..63]
    var deriveNode = cast[HDNode](allocShared0(sizeof(HDNodeObj)))
    deriveNode.depth = node.depth + 1
    deriveNode.fingerprint = ripemd160hash(node.publicKey).toBytes.toUint32BE
    deriveNode.childNumber = childNumber
    deriveNode.chainCode = chainCode
    deriveNode.privateKey = privateKey.tweakAdd(node.privateKey)
    deriveNode.publicKey = deriveNode.privateKey.pub
    deriveNode.versionPrv = node.versionPrv
    deriveNode.versionPub = node.versionPub
    result = deriveNode

  proc derive*(node: HDNode, index: uint32): HDNode {.exportc: "bip32_$1".} =
    var childNumber = index
    var data = (node.publicKey, childNumber).toBytesBE
    var I = sha512.hmac(node.chainCode.toSeq, data.toSeq).data.toBytes
    var privateKey: PrivateKey = I[0..31]
    var chainCode: ChainCode = I[32..63]
    var deriveNode = cast[HDNode](allocShared0(sizeof(HDNodeObj)))
    deriveNode.depth = node.depth + 1
    deriveNode.fingerprint = ripemd160hash(node.publicKey).toBytes.toUint32BE
    deriveNode.childNumber = childNumber
    deriveNode.chainCode = chainCode
    if node.privateKey.len == 32:
      deriveNode.privateKey = privateKey.tweakAdd(node.privateKey)
      deriveNode.publicKey = deriveNode.privateKey.pub
    else:
      deriveNode.publicKey = node.publicKey.pubObj.tweakAdd(privateKey).pub
    deriveNode.versionPrv = node.versionPrv
    deriveNode.versionPub = node.versionPub
    result = deriveNode

  proc getAddress*(networkId: NetworkId, node: HDNode): string =
    var network = getNetwork(networkId)
    result = node.publicKey.toAddress(network)

  proc getSegwitAddress*(networkId: NetworkId, node: HDNode): string =
    var network = getNetwork(networkId)
    result = node.publicKey.toSegwitAddress(network)

  proc address*(node: HDNode, networkId: NetworkId): cstring {.exportc: "bip32_$1".} =
    var network = getNetwork(networkId)
    var s = node.publicKey.toAddress(network)
    node.address.set(s)

  proc segwitAddress*(node: HDNode, networkId: NetworkId): cstring {.exportc: "bip32_$1".} =
    var network = getNetwork(networkId)
    var s = node.publicKey.toSegwitAddress(network)
    node.segwitAddress.set(s)

  proc address*(node: HDNode, networkId: NetworkId, outAddress: ptr cstring): cint {.exportc: "bip32_$1_ex".} =
    var network = getNetwork(networkId)
    var s = node.publicKey.toAddress(network)
    node.address.set(s)
    outAddress[] = node.address
    result = s.len.cint

  proc segwitAddress*(node: HDNode, networkId: NetworkId, outAddress: ptr cstring): cint {.exportc: "bip32_$1_ex".} =
    var network = getNetwork(networkId)
    var s = node.publicKey.toSegwitAddress(network)
    node.segwitAddress.set(s)
    outAddress[] = node.segwitAddress
    result = s.len.cint

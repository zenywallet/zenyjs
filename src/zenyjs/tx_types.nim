# Copyright (c) 2020 zenywallet

when defined(js):
  import std/jsffi
  import arraylib
  import script

  type
    Flags* = distinct uint8

    Witness* = distinct Array[byte]

    Sig* = distinct Array[byte]

    TxIn* = tuple[tx: Hash, n: uint32, sig: Sig, sequence: uint32]

    TxOut* = tuple[value: uint64, script: Script]

    TxObj* = object
      ver*: int32
      flags*: Flags
      ins*: Array[TxIn]
      outs*: Array[TxOut]
      witnesses*: Array[Array[Witness]]
      locktime*: uint32

    Tx* = object
      handle*: JsObject

    Hash* {.borrow: `.`.} = distinct Array[byte]

  var TxMod* = JsObject{}

  proc `=destroy`*(tx: var Tx) =
    if not tx.handle.isNil:
      TxMod.free(tx)
      tx.handle = jsNull

  proc `=copy`*(a: var Tx; b: Tx) =
    `=destroy`(a)
    if not b.handle.isNil:
      a.handle = TxMod.duplicate(b.handle)

  proc `=sink`*(a: var Tx; b: Tx) =
    `=destroy`(a)
    if not b.handle.isNil:
      a.handle = b.handle

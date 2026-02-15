# Copyright (c) 2020 zenywallet

import arraylib
import script
import hash
export hash

type
  Flags* = distinct uint8

  Witness* {.borrow: `.`.} = distinct Array[byte]

  Sig* {.borrow: `.`.} = distinct Array[byte]

  TxIn* = tuple[tx: Hash, n: uint32, sig: Sig, sequence: uint32]

  TxOut* = tuple[value: uint64, script: Script]

  TxObj* = object
    ver*: int32
    flags*: Flags
    ins*: Array[TxIn]
    outs*: Array[TxOut]
    witnesses*: Array[Array[Witness]]
    locktime*: uint32

converter toArray*(data: Witness): Array[byte] = cast[Array[byte]](data)

when defined(js):
  import std/jsffi

  type
    Tx* = object
      handle*: JsObject

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

else:
  import custom

  type
    TxHandle* = ptr TxObj

    Tx* = object of HandleObj[TxHandle]

  proc free*(tx: Tx) {.exportc: "tx_$1".} =
    if tx.handle.isNil: return
    let tx = tx.handle
    `=destroy`(tx.witnesses)
    `=destroy`(tx.outs)
    `=destroy`(tx.ins)
    tx.deallocShared()

  proc `=destroy`*(tx: var Tx) = tx.free()

  proc `=copy`*(a: var Tx; b: Tx) =
    if a.handle == b.handle: return
    `=destroy`(a)
    wasMoved(a)
    if b.handle != nil:
      a.handle = cast[typeof(a.handle)](allocShared0(sizeof(TxObj)))
      a.handle.ver = b.handle.ver
      a.handle.flags = b.handle.flags
      a.handle.ins = b.handle.ins
      a.handle.outs = b.handle.outs
      a.handle.witnesses = b.handle.witnesses
      a.handle.locktime = b.handle.locktime

  proc `=sink`*(a: var Tx; b: Tx) =
    `=destroy`(a)
    wasMoved(a)
    a.handle = b.handle

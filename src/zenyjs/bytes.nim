# Copyright (c) 2020 zenywallet

import hex
export hex

when defined(js):
  when not defined(CSTRING_SAFE):
    proc toString*(s: seq[byte]): string = cast[string](s)

  proc toString*(s: openarray[byte]): string =
    for c in s:
      result.add(cast[char](c))

  proc toString*(buf: ptr UncheckedArray[byte], size: SomeInteger): string =
    for i in 0..<size:
      result.add(cast[char](buf[i]))

  proc `$`*(data: seq[byte]): string =
    if data.len > 0:
      result = hex.toHex(data)
    else:
      result = ""

else:
  import std/sequtils
  import std/strutils
  import std/endians
  import std/algorithm
  import opcodes
  import arraylib
  import hash
  export hash

  type
    VarInt* = distinct int

    VarStr* = distinct string

    Pad* = distinct int

    FixedStr* = ref object
      data*: string
      size*: int

    Hash160* {.borrow: `.`.} = distinct Array[byte]

    PushData* {.borrow: `.`.} = distinct Array[byte]


  proc toBytes*(x: SomeOrdinal | SomeFloat): Array[byte] =
    when sizeof(x) == 1:
      @^[byte x]
    else:
      result.newArray(sizeof(x))
      when sizeof(x) == 2:
        littleEndian16(addr result[0], unsafeAddr x)
      elif sizeof(x) == 4:
        littleEndian32(addr result[0], unsafeAddr x)
      elif sizeof(x) == 8:
        littleEndian64(addr result[0], unsafeAddr x)
      else:
        raiseAssert("toBytes: unsupported type")

  proc toBytesBE*(x: SomeOrdinal | SomeFloat): Array[byte] =
    when sizeof(x) == 1:
      @^[byte x]
    else:
      result.newArray(sizeof(x))
      when sizeof(x) == 2:
        bigEndian16(addr result[0], unsafeAddr x)
      elif sizeof(x) == 4:
        bigEndian32(addr result[0], unsafeAddr x)
      elif sizeof(x) == 8:
        bigEndian64(addr result[0], unsafeAddr x)
      else:
        raiseAssert("toBytes: unsupported type")

  proc toBE*[T](x: T): T =
    when sizeof(x) == 1:
      x
    elif sizeof(x) == 2:
      bigEndian16(addr result, unsafeAddr x)
    elif sizeof(x) == 4:
      bigEndian32(addr result, unsafeAddr x)
    elif sizeof(x) == 8:
      bigEndian64(addr result, unsafeAddr x)
    else:
      raiseAssert("toBE: unsupported type")

  proc varInt*[T](val: T): Array[byte] =
    if val < 0xfd:
      @^[byte val]
    elif val <= 0xffff:
      concat(@^[byte 0xfd], (uint16(val)).toBytes)
    elif val <= 0xffffffff:
      concat(@^[byte 0xfe], (uint32(val)).toBytes)
    else:
      concat(@^[byte 0xff], (uint64(val)).toBytes)

  proc varStr*(s: string): Array[byte] {.inline.} = concat(varInt(s.len), cast[Array[byte]](s))

  proc pushData*(data: Array[byte]): Array[byte] =
    if data.len <= 0:
      raiseAssert("pushData: empty")
    elif data.len < OP_PUSHDATA1.ord:
      result = concat(@^[byte data.len], data)
    elif data.len <= 0xff:
      result = concat(@^[byte OP_PUSHDATA1], (data.len).uint8.toBytes, data)
    elif data.len <= 0xffff:
      result = concat(@^[byte OP_PUSHDATA2], (data.len).uint16.toBytes, data)
    elif data.len <= 0xffffffff:
      result = concat(@^[byte OP_PUSHDATA4], (data.len).uint32.toBytes, data)
    else:
      raiseAssert("pushData: overflow")

  proc pushData*(data: openarray[byte]): Array[byte] {.inline.} = pushData(data)

  proc pad*(len: int): Array[byte] {.inline.} = newArray[byte](len)

  proc pad*(len: int, val: byte): Array[byte] {.inline.} =
    result = newArrayUninitialized[byte](len)
    for i in 0..<len:
      result[i] = val

  proc newFixedStr*(data: string, size: int): FixedStr {.inline.} = FixedStr(data: data, size: size)

  proc fixedStr*(str: string, size: int): Array[byte] {.inline.} =
    if size < str.len:
      concat(cast[seq[byte]](str)[0..<size]).toArray
    else:
      concat(cast[seq[byte]](str).toArray, pad(size - str.len))

  proc toBytes*(x: Array[byte]): Array[byte] {.inline.} = x
  proc toBytes*(x: openarray[byte]): Array[byte] {.inline.} = x.toArray
  proc toBytes*(val: VarInt): Array[byte] {.inline.} = varInt(cast[int](val))
  proc toBytes*(str: VarStr): Array[byte] {.inline.} = varStr(cast[string](str))
  proc toBytes*(len: Pad): Array[byte] {.inline.} = pad(cast[int](len))
  proc toBytes*(fstr: FixedStr): Array[byte] {.inline.} = fixedStr(fstr.data, fstr.size)
  proc toBytes*(hash: Hash): Array[byte] {.inline.} = cast[Array[byte]](hash)
  proc toBytes*(hash: Hash160): Array[byte] {.inline.} = cast[Array[byte]](hash)
  proc toBytes*(p: PushData): Array[byte] {.inline.} = pushData(cast[Array[byte]](p))
  proc toBytes*(x: string): Array[byte] {.inline.} =
    result.newArray(x.len)
    for i in 0..x.len-1:
      result[i] = x[i].byte

  proc toBytes*(obj: tuple | object): Array[byte] =
    var s: Array[Array[byte]]
    for val in obj.fields:
      var b = val.toBytes
      s.add(b)
    concat(s)

  proc toBytes*[T](obj: openarray[T]): Array[byte] =
    var s: Array[Array[byte]]
    for val in obj:
      var b = val.toBytes
      s.add(b)
    concat(s)

  proc toBytes*[T](obj: Array[T]): Array[byte] =
    var s: Array[Array[byte]]
    for val in obj:
      var b = val.toBytes
      s.add(b)
    concat(s)

  proc toBytes*(obj: ref tuple | ref object | ptr tuple | ptr object): Array[byte] =
    var s: Array[Array[byte]]
    for val in obj[].fields:
      var b = val.toBytes
      s.add(b)
    concat(s)

  proc toBytes*(buf: ptr UncheckedArray[byte], size: SomeInteger): Array[byte] =
    result = newArrayOfCap[byte](size)
    for i in 0..<size:
      result.add(buf[i])

  proc Bytes*(args: varargs[Array[byte], toBytes]): Array[byte] = concat(args)

  proc toBytesBE*(x: Array[byte]): Array[byte] {.inline.} = x
  proc toBytesBE*(x: openarray[byte]): Array[byte] {.inline.} = x.toArray
  proc toBytesBE*(hash: Hash): Array[byte] {.inline.} = cast[Array[byte]](hash)
  proc toBytesBE*(hash: Hash160): Array[byte] {.inline.} = cast[Array[byte]](hash)
  proc toBytesBE*(x: string): Array[byte] {.inline.} =
    result.newArray(x.len)
    for i in 0..x.len-1:
      result[i] = x[i].byte

  proc toBytesBE*(obj: tuple | object): Array[byte] =
    var s: Array[Array[byte]]
    for val in obj.fields:
      var b = val.toBytesBE
      var a = newArrayUninitialized[byte](b.len)
      for i in 0..<b.len:
        a[i] = b[i]
      s.add(a)
    concat(s)

  proc toBytesBE*(obj: ref tuple | ref object | ptr tuple | ptr object): Array[byte] =
    var s: Array[Array[byte]]
    for val in obj[].fields:
      var b = val.toBytesBE
      var a = newArrayUninitialized[byte](b.len)
      for i in 0..<b.len:
        a[i] = b[i]
      s.add(a)
    concat(s)

  proc BytesBE*(x: SomeOrdinal | SomeFloat): Array[byte] {.inline.} = x.toBytesBE
  proc BytesBE*(args: varargs[Array[byte], toBytesBE]): Array[byte] = concat(args)

  proc toBytesFromHex*(s: string): Array[byte] =
    if s.len mod 2 == 0:
      result = newArrayOfCap[byte](s.len div 2)
      for i in countup(0, s.len - 2, 2):
        result.add(strutils.fromHex[byte](s[i..i+1]))

  proc toBytes*(x: Hex): Array[byte] {.inline.} = x.string.toBytesFromHex()

  proc toReverse*(x: Array[byte]): Array[byte] =
    var b = x.toSeq
    algorithm.reverse(b)
    b.toArray

  proc to*(x: var byte, T: typedesc): T {.inline.} = cast[ptr T](addr x)[]
  proc toUint8*(x: var byte): uint8 {.inline.} = x.uint8
  proc toUint16*(x: var byte): uint16 {.inline.} = cast[ptr uint16](addr x)[]
  proc toUint32*(x: var byte): uint32 {.inline.} = cast[ptr uint32](addr x)[]
  proc toUint64*(x: var byte): uint64 {.inline.} = cast[ptr uint64](addr x)[]

  proc to*(x: openarray[byte], T: typedesc): T {.inline.} = cast[ptr T](unsafeAddr x[0])[]
  proc toUint8*(x: openarray[byte]): uint8 {.inline.} = x[0].uint8
  proc toUint16*(x: openarray[byte]): uint16 {.inline.} = cast[ptr uint16](unsafeAddr x[0])[]
  proc toUint32*(x: openarray[byte]): uint32 {.inline.} = cast[ptr uint32](unsafeAddr x[0])[]
  proc toUint64*(x: openarray[byte]): uint64 {.inline.} = cast[ptr uint64](unsafeAddr x[0])[]

  proc to*(x: Array[byte], T: typedesc): T {.inline.} = cast[ptr T](unsafeAddr x[0])[]
  proc toUint8*(x: Array[byte]): uint8 {.inline.} = x[0].uint8
  proc toUint16*(x: Array[byte]): uint16 {.inline.} = cast[ptr uint16](unsafeAddr x[0])[]
  proc toUint32*(x: Array[byte]): uint32 {.inline.} = cast[ptr uint32](unsafeAddr x[0])[]
  proc toUint64*(x: Array[byte]): uint64 {.inline.} = cast[ptr uint64](unsafeAddr x[0])[]

  proc toBE*(x: var byte, T: typedesc): T {.inline.} = to(x, T)
  proc toUint8BE*(x: var byte): uint8 {.inline.} = x.uint8
  proc toUint16BE*(x: var byte): uint16 {.inline.} = x.toUint16.toBE
  proc toUint32BE*(x: var byte): uint32 {.inline.} = x.toUint32.toBE
  proc toUint64BE*(x: var byte): uint64 {.inline.} = x.toUint64.toBE

  proc toBE*(x: openarray[byte], T: typedesc): T {.inline.} = cast[ptr T](unsafeAddr x[0])[]
  proc toUint8BE*(x: openarray[byte]): uint8 {.inline.} = x[0].uint8
  proc toUint16BE*(x: openarray[byte]): uint16 {.inline.} = x.toUint16.toBE
  proc toUint32BE*(x: openarray[byte]): uint32 {.inline.} = x.toUint32.toBE
  proc toUint64BE*(x: openarray[byte]): uint64 {.inline.} = x.toUint64.toBE

  proc toBE*(x: Array[byte], T: typedesc): T {.inline.} = cast[ptr T](unsafeAddr x[0])[]
  proc toUint8BE*(x: Array[byte]): uint8 {.inline.} = x[0].uint8
  proc toUint16BE*(x: Array[byte]): uint16 {.inline.} = x.toUint16.toBE
  proc toUint32BE*(x: Array[byte]): uint32 {.inline.} = x.toUint32.toBE
  proc toUint64BE*(x: Array[byte]): uint64 {.inline.} = x.toUint64.toBE

  proc toHash*(x: var byte): Hash {.inline.} = Hash((cast[ptr array[32, byte]](addr x)[]).toArray)
  proc toHash*(x: Array[byte]): Hash {.inline.} = Hash(x)
  proc toHash*(x: openarray[byte]): Hash {.inline.} = Hash(x.toArray)
  proc toHash*(x: Hex): Hash {.inline} = x.toBytes.toReverse.Hash

  proc toHash160*(x: var byte): Hash160 {.inline.} = Hash160((cast[ptr array[20, byte]](addr x)[]).toArray)
  proc toHash160*(x: Array[byte]): Hash160 {.inline.} = Hash160(x)
  proc toHash160*(x: openarray[byte]): Hash160 {.inline.} = Hash160(x.toArray)

  when not defined(CSTRING_SAFE):
    proc toString*(s: seq[byte]): string = cast[string](s)

  proc toString*(s: openarray[byte]): string =
    result = newStringOfCap(len(s))
    for c in s:
      result.add(cast[char](c))

  when not defined(ARRAY_USE_SEQ):
    proc toString*(s: Array[byte]): string =
      result = newStringOfCap(len(s))
      for c in s:
        result.add(cast[char](c))

  proc toString*(buf: ptr UncheckedArray[byte], size: SomeInteger): string =
    result = newStringOfCap(size)
    for i in 0..<size:
      result.add(cast[char](buf[i]))

  proc `$`*(data: seq[byte]): string =
    if data.len > 0:
      result = hex.toHex(data)
    else:
      result = ""

  when not defined(ARRAY_USE_SEQ):
    proc `$`*(data: Array[byte]): string =
      if data.len > 0:
        result = hex.toHex(toOpenArray(data.data, 0, data.len - 1))
      else:
        result = ""

  proc `$`*(val: VarInt): string = "VarInt(" & $cast[int](val) & ")"

  proc `$`*(str: VarStr): string = "VarStr(\"" & $cast[string](str) & "\")"

  proc `$`*(len: Pad): string = "Pad(" & $cast[int](len) & ")"

  proc `$`*(fstr: FixedStr): string = "FixedStr(\"" & fstr.data & "\", " & $fstr.size & ")"

  proc `$`*(data: Hash): string =
    var b = cast[Array[byte]](data).toSeq
    algorithm.reverse(b)
    hex.toHex(b)

  proc `$`*(data: Hash160): string = $data.toBytes

  proc `$`*(p: PushData): string =
    var op: string
    var b = cast[Array[byte]](p)
    var len = b.len
    if len < OP_PUSHDATA1.ord:
      op = "PushData"
    elif len <= 0xff:
      op = "PushData1"
    elif len <= 0xffff:
      op = "PushData2"
    elif len <= 0xffffffff:
      op = "PushData4"
    else:
      raiseAssert("pushdata overflow")
    result = op & "(" & $len & ", " & $b & ")"

  proc `$`*(o: ref tuple | ref object | ptr tuple | ptr object): string = $o[]

  proc `==`*(x, y: Hash | Hash160): bool = x.toBytes == y.toBytes

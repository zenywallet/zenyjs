# Copyright (c) 2022 zenywallet

when defined(js):
  import jsffi
  import jslib

  type
    Array*[T] = object
      handle: JsObject
      cache: cint

    ArrayByte* = Array[byte]

    Hex* = distinct string

    ArrayError* = object of CatchableError

    ArrayDirty {.pure.} = enum
      None
      Handle
      Data

    ArrayCache[T] = object
      data: seq[T]
      dirty: ArrayDirty

  var ArrayMod = JsObject{}
  var Module: JsObject

  var arrayCache = JsObject{}
  var arrayCacheIdx = 1.cint

  proc getNewArrayCacheIdx(): cint =
    var flag = false
    while arrayCache[arrayCacheIdx] != jsNull:
      if arrayCacheIdx >= cint.high:
        if flag: raise
        flag = true
        arrayCacheIdx = 1.cint
      else:
        inc(arrayCacheIdx)
    result = arrayCacheIdx

  proc handle*[T](a: Array[T]): JsObject =
    when T is byte:
      if a.cache != 0 and arrayCache[a.cache] != jsNull:
        var cache = arrayCache[a.cache].to(ArrayCache[byte])
        if cache.dirty == ArrayDirty.Data:
          var pData = Module.HEAPU32[(a.handle.to(cint) + 8) div 4].to(int)
          for i, d in cache.data:
            Module.HEAPU8[pData + i] = d
          cache.data = @[]
          cache.dirty = ArrayDirty.None
    else:
      discard
    result = a.handle

  proc init*(module: JsObject) =
    Module = module
    ArrayMod.newArrayByte = Module.cwrap("array_new", jsNull, [NumVar, NumVar])
    ArrayMod.destroy = Module.cwrap("array_destroy", jsNull, [NumVar])

  proc newArray*[T](len: Natural or JsObject): Array[T] =
    when not T is byte: raise
    result.handle = Module.malloc(12)
    discard ArrayMod.newArrayByte(len, result.handle)

  proc `=destroy`*[T](x: var Array[T]) =
    if not x.handle.isNull:
      ArrayMod.destroy(x.handle)
      Module.free(x.handle)
      x.handle = jsNull
      if x.cache != 0.cint:
        discard jsDelete(arrayCache[x.cache])
        x.cache = 0.cint

  proc `=copy`*[T](a: var Array[T]; b: Array[T]) =
    raise newException(ArrayError, "unsupported =copy")

  proc `=sink`*[T](a: var Array[T]; b: Array[T]) =
    `=destroy`(a)
    wasMoved(a)
    a.handle = b.handle
    a.cache = b.cache

  proc init*[T](x: var Array[T]) =
    `=destroy`(x)
    x.handle = Module.malloc(12)
    var zeroData = newUint8Array(12)
    Module.HEAPU8.set(zeroData, x.handle)

  proc newArray*[T](): Array[T] = result.init()

  proc len*[T](x: Array[T]): int = Module.HEAPU32[x.handle.to(cint) div 4].to(int)

  proc cap*[T](x: Array[T]): int = Module.HEAPU32[(x.handle.to(cint) + 4) div 4].to(int)

  proc data*[T](x: Array[T]): int = Module.HEAPU32[(x.handle.to(cint) + 8) div 4].to(int)

  proc toUint8Array*[T](x: Array[T]): Uint8Array =
    var p32 = x.handle.to(cint) div 4
    when T is byte:
      newUint8Array(Module.HEAPU8.buffer, Module.HEAPU32[p32 + 2].to(int), Module.HEAPU32[p32].to(int)).slice().to(Uint8Array)
    else:
      discard

  proc toUint8Array*[T](x: seq[T]): Uint8Array =
    when T is byte:
      result = newUint8Array(x.len)
      for i, d in x:
        result[i] = d
    else:
      discard

  proc toString*(x: Array[byte]): cstring =
    var p32 = x.handle.to(cint) div 4
    var uint8Array = newUint8Array(Module.HEAPU8.buffer, Module.HEAPU32[p32 + 2].to(int), Module.HEAPU32[p32].to(int)).slice()
    let textdec = newTextDecoder()
    result = textdec.decode(uint8Array).to(cstring)

  proc toBytes*(x: Array[byte]): Array[byte] = x

  proc toBytes*(uint8Array: Uint8Array): Array[byte] =
    var arrayLen = uint8Array.length
    result = newArray[byte](arrayLen)
    discard Module.HEAPU8.set(uint8Array, result.data.cint)

  proc toBytes*(s: cstring): Array[byte] =
    var uint8Array = strToUint8Array(s)
    uint8Array.toBytes

  proc toBytes*(x: Hex): Array[byte] = x.cstring.hexToUint8Array.toBytes

  proc toHex*(x: Array[byte]): cstring =
    var cacheJsObj = arrayCache[x.cache]
    if cacheJsObj != jsNull:
      var cache = cacheJsObj.to(ArrayCache[byte])
      if cache.dirty == ArrayDirty.Data:
        return uint8ArrayToHex(cache.data.toUint8Array)
    var arrayObj = newUint32Array(newUint8Array(Module.HEAPU8.buffer, x.handle.to(cint), 12).slice().buffer, 0, 3)
    var uint8Array = newUint8Array(Module.HEAPU8.buffer, arrayObj[2].to(int), arrayObj[0].to(int)).slice()
    result = uint8ArrayToHex(uint8Array)

  proc `$`*(x: Array[byte]): string = $x.toHex

  proc `==`*[T](x: Array[T], y: Array[T]): bool =
    if x.len != y.len:
      return false
    let xa = x.toUint8Array
    let ya = y.toUint8Array
    for f in 0..<x.len:
      if xa[f] != ya[f]:
        return false
    result = true

  proc `@^`*[IDX, T](a: sink array[IDX, T]): Array[T] =
    when T is byte:
      var y = newSeq[byte](a.len)
      for i in 0..a.len-1:
        y[i] = a[i]
      var cacheIdx = getNewArrayCacheIdx()
      arrayCache[cacheIdx] = ArrayCache[byte](data: y, dirty: ArrayDirty.Data)
      result = newArray[T](a.len)
      result.cache = cacheIdx
      echo y
    else:
      discard

  template borrowArrayProc*(typ: typedesc) =
    proc len*(x: typ): int {.borrow.}
    proc cap*(x: typ): int {.borrow.}
    proc data*(x: typ): int {.borrow.}
    proc toUint8Array*(x: typ): Uint8Array {.borrow.}
    proc toHex*(x: typ): cstring {.borrow.}
    proc handle*(x: typ): JsObject {.borrow.}

else:
  when defined(emscripten):
    const EXPORTED_FUNCTIONS* = ["_array_new", "_array_destroy"]

  import json

  type
    Array*[T] = object
      len*, cap*: int
      data*: ptr UncheckedArray[T]

    ArrayByte* = Array[byte]

    Hex* = distinct string

  proc `=destroy`*[T](x: var Array[T]) =
    if x.data != nil:
      x.data.deallocShared()
      x.data = nil
      x.len = 0
      x.cap = 0

  proc `=copy`*[T](a: var Array[T]; b: Array[T]) =
    if a.data == b.data: return
    `=destroy`(a)
    wasMoved(a)
    a.len = b.len
    a.cap = b.cap
    if b.data != nil:
      a.data = cast[typeof(a.data)](allocShared0(sizeof(T) * a.cap))
      copyMem(a.data, b.data, sizeof(T) * a.len)

  proc `=sink`*[T](a: var Array[T]; b: Array[T]) =
    `=destroy`(a)
    wasMoved(a)
    a.len = b.len
    a.cap = b.cap
    a.data = b.data

  template nextCap(cap: int): int =
    if cap <= 16:
      32
    else:
      cap * 2

  proc add*[T](x: var Array[T]; y: sink Array[T]) =
    let newLen = x.len + y.len
    if x.cap < newLen:
      x.cap = nextCap(newLen)
      x.data = cast[ptr UncheckedArray[T]](reallocShared0(x.data, sizeof(T) * x.len, sizeof(T) * x.cap))
    copyMem(addr x.data[x.len], addr y.data[0], sizeof(T) * y.len)
    x.len = newLen

  proc add*[T](x: var Array[T]; y: sink T) =
    let newLen = x.len + 1
    if x.cap < newLen:
      x.cap = nextCap(newLen)
      x.data = cast[ptr UncheckedArray[T]](reallocShared0(x.data, sizeof(T) * x.len, sizeof(T) * x.cap))
    x.data[x.len] = y
    x.len = newLen

  proc add*[T](x: var Array[T]; y: sink seq[T]) =
    let newLen = x.len + y.len
    if x.cap < newLen:
      x.cap = nextCap(newLen)
      x.data = cast[ptr UncheckedArray[T]](reallocShared0(x.data, sizeof(T) * x.len, sizeof(T) * x.cap))
    copyMem(addr x.data[x.len], unsafeAddr y[0], sizeof(T) * y.len)
    x.len = newLen

  proc add*[T](x: var Array[T]; y: sink openArray[T]) =
    let newLen = x.len + y.len
    if x.cap < newLen:
      x.cap = nextCap(newLen)
      x.data = cast[ptr UncheckedArray[T]](reallocShared0(x.data, sizeof(T) * x.len, sizeof(T) * x.cap))
    copyMem(addr x.data[x.len], unsafeAddr y[0], sizeof(T) * y.len)
    x.len = newLen

  template `[]`*[T](x: Array[T]; i: Natural): T =
    #assert 0 <= i and i < x.len
    x.data[i]

  template `[]`*[T](x: ptr Array[T]; i: Natural): T =
    #assert 0 <= i and i < x[].len
    x[].data[i]

  template `[]=`*[T](x: var Array[T]; i: Natural; y: sink T) =
    #assert 0 <= i and i < x.len
    x.data[i] = y

  proc len*[T](x: Array[T]): int {.inline.} = x.len

  proc newArray*[T](len: Natural): Array[T] =
    let size = sizeof(T) * len
    result.data = cast[typeof(result.data)](allocShared0(size))
    result.len = len
    result.cap = size

  proc newArray*[T](a: var Array[T], len: Natural) =
    let size = sizeof(T) * len
    a.data = cast[typeof(a.data)](allocShared0(size))
    a.len = len
    a.cap = size

  proc newArrayUninitialized*[T](len: Natural): Array[T] =
    let size = sizeof(T) * len
    result.data = cast[typeof(result.data)](allocShared(size))
    result.len = len
    result.cap = size

  proc newArrayUninitialized*[T](a: var Array[T], len: Natural): Array[T] =
    let size = sizeof(T) * len
    a.data = cast[typeof(a.data)](allocShared(size))
    a.len = len
    a.cap = size

  proc newArrayOfCap*[T](len: Natural): Array[T] =
    let size = sizeof(T) * len
    result.data = cast[typeof(result.data)](allocShared0(size))
    result.len = 0
    result.cap = size

  proc newArrayOfCap*[T](a: var Array[T], len: Natural) =
    let size = sizeof(T) * len
    a.data = cast[typeof(a.data)](allocShared0(size))
    a.len = 0
    a.cap = size

  proc newArray*[T](buf: ptr UncheckedArray[T], len: Natural): Array[T] =
    let size = sizeof(T) * len
    result.data = cast[typeof(result.data)](allocShared0(size))
    copyMem(result.data, buf, size)
    result.len = size
    result.cap = size

  proc toArray*[T](x: openArray[T]): Array[T] =
    if x.len > 0:
      let size = sizeof(T) * x.len
      result.data = cast[typeof(result.data)](allocShared0(size))
      copyMem(result.data, unsafeAddr x[0], size)
      result.len = x.len
      result.cap = size

  proc toArray*[T](x: seq[T]): Array[T] =
    if x.len > 0:
      let size = sizeof(T) * x.len
      result.data = cast[typeof(result.data)](allocShared0(size))
      copyMem(result.data, unsafeAddr x[0], size)
      result.len = x.len
      result.cap = size

  proc toSeq*[T](x: Array[T]): seq[T] =
    result.newSeq(x.len)
    for i in 0..<x.len:
      result[i] = x[i]

  proc `$`*[T](a: Array[T]): string =
    if a.len > 0:
      when T is string:
        result = "@^[\"" & $a[0]
        for i in 1..<a.len:
          result.add("\", \"" & $a[i])
        result.add("\"]")
      else:
        result = "@^[" & $a[0]
        for i in 1..<a.len:
          result.add(", " & $a[i])
        result.add("]")
    else:
      result = "@^[]"

  proc toHex*[T](a: Array[T]): string = a.toBytes.toHex

  iterator items*[T](a: Array[T]): lent T =
    for i in 0..<a.len:
      yield a.data[i]

  iterator pairs*[T](a: Array[T]): tuple[key: int, val: lent T] =
    for i in 0..<a.len:
      yield (i, a.data[i])

  proc high*[T](x: Array[T]): int {.inline.} = x.len - 1

  proc low*[T](x: Array[T]): int {.inline.} = 0

  proc `@^`*[IDX, T](a: sink array[IDX, T]): Array[T] =
    result.newArray(a.len)
    for i in 0..a.len-1:
      result[i] = a[i]

  proc `@^`*[T](a: sink seq[T]): Array[T] =
    result.newArray(a.len)
    for i in 0..a.len-1:
      result[i] = a[i]

  proc concat*[T](arrays: varargs[Array[T]]): Array[T] =
    var allLen = 0
    for a in arrays:
      inc(allLen, a.len)
    result.newArray(allLen)
    var i = 0
    for a in arrays:
      for item in a:
        result[i] = item
        inc(i)

  proc concat*[T](arrays: Array[Array[T]]): Array[T] =
    var allLen = 0
    for a in arrays:
      inc(allLen, a.len)
    result.newArray(allLen)
    var i = 0
    for a in arrays:
      for item in a:
        result[i] = item
        inc(i)

  proc `[]`*[T](a: Array[T]; i: BackwardsIndex): T {.inline.} =
    a[a.len - int(i) + low(a)]

  proc `[]`*[T](a: var Array[T]; i: BackwardsIndex): var T {.inline.} =
    a[a.len - int(i) + low(a)]

  proc `[]`*[T; U, V: Ordinal](a: Array[T]; x: HSlice[U, V]): Array[T] =
    var xa, xb: int
    when x.a is BackwardsIndex:
      xa = a.len - x.a.int
    else:
      xa = x.a.int
    when x.b is BackwardsIndex:
      xb = a.len - x.b.int
    else:
      xb = x.b.int
    let len = xb - xa + 1
    result.newArray(len)
    var idx = 0
    for i in xa..xb:
      result[idx] = a[i]
      inc(idx)

  proc empty*[T](x: var Array[T]) =
    `=destroy`(x)

  proc clear*[T](x: var Array[T]) {.inline.} =
    x.len = 0

  proc del*[T](x: var Array[T]; i: Natural) =
    let last = x.high
    x[i] = x[last]
    x.len = last

  proc delete*[T](x: var Array[T]; i: Natural) =
    let last = x.high
    if i != last:
      moveMem(addr x[i], addr x[i + 1], last - i)
    x.len = last

  proc `==`*[T](x: Array[T] or seq[T], y: Array[T]): bool =
    if x.len != y.len:
      return false
    for f in x.low..x.high:
      if x[f] != y[f]:
        return false
    result = true

  template `==`*[T](x: Array[T], y: seq[T]): bool = `==`(y, x)

  proc setLen*[T](x: var Array[T], newLen: Natural) =
    if x.cap < newLen:
      x.cap = nextCap(newLen)
      x.data = cast[ptr UncheckedArray[T]](reallocShared0(x.data, sizeof(T) * x.len, sizeof(T) * x.cap))
    x.len = newlen

  proc toString*(x: Array[byte] or Array[char]): string =
    let xlen = len(x)
    result = newString(xlen)
    copyMem(addr result[0], x.data, xlen)

  proc `%`*[T](a: Array[T]): JsonNode = %a.toSeq

  when defined(emscripten):
    proc newArrayByte*(len: int, result: var Array[byte]) {.exportc: "array_new".} =
      result.newArray(len)

    proc destroy*(x: var Array[byte]) {.exportc: "array_destroy".} = `=destroy`(x)

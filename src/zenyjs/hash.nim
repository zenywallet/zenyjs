# Copyright (c) 2020 zenywallet

import arraylib

when defined(js):
  type
    Hash* = InternalExportedHash
else:
  type
    Hash* {.borrow: `.`.} = distinct Array[byte]

when defined(js):
  import jsffi
  import jslib except Array
  import algorithm
  import hex

  borrowArrayProc(Hash)

  proc `$`*(data: Hash): string =
    var b = cast[Array[byte]](data).toSeq
    algorithm.reverse(b)
    $b.toHex

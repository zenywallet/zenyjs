# Copyright (c) 2020 zenywallet

import arraylib

type
  Hash* {.borrow: `.`.} = distinct Array[byte]

when defined(js):
  import jsffi
  import jslib except Array
  import algorithm

  borrowArrayProc(Hash)

  proc `$`*(data: Hash): string =
    var b = cast[Array[byte]](data).toSeq
    algorithm.reverse(b)
    var a = newArray[byte](data.len)
    for i in 0..<b.len:
      a[i] = b[i]
    $a.toHex

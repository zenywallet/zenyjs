# Copyright (c) 2021 zenywallet

import seed_native

proc cryptSeed*(buf: ptr UncheckedArray[byte], size: int): int {.importc: "crypt_seed", cdecl.}

when not defined(js):
  proc cryptSeed*(buf: openArray[byte]): int {.inline.} =
    cryptSeed(cast[ptr UncheckedArray[byte]](buf), buf.len)

  proc cryptSeed*(size: int): seq[byte] =
    var a = newSeq[byte](size)
    var ret = cryptSeed(cast[ptr UncheckedArray[byte]](addr a[0]), size)
    if ret == 0:
      result = a

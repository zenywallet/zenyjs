# Copyright (c) 2023 zenywallet

import arraylib
import eckey
import seed

proc randomKey*(): tuple[prv: PrivateKey, pub: PublicKey] =
  while true:
    try:
      let prv = cryptSeed(32).PrivateKey
      return (prv, prv.pub)
    except:
      let e = getCurrentException()
      echo e.name, ": ", e.msg


when isMainModule:
  import bytes
  import address

  var pair = randomKey()
  echo pair
  echo pair.pub.toAddress()

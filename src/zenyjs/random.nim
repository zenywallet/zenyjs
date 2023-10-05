# Copyright (c) 2023 zenywallet

when defined(js):
  import arraylib
  import eckey
  import seed
  export seed

  proc randomKey*(): tuple[prv: PrivateKey, pub: PublicKey] =
    while true:
      try:
        let s = cryptSeed(32)
        let prv = s.PrivateKey
        let pub = prv.pub
        return (prv, pub)
      except SeedError:
        raise newException(SeedError, getCurrentExceptionMsg())
      except:
        let e = getCurrentException()
        echo e.name, ": ", e.msg

else:
  import eckey
  import seed
  import custom
  export seed

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

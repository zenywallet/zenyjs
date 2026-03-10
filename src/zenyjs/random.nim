# Copyright (c) 2023 zenywallet

when defined(js):
  import eckey
  import seed
  export seed

  proc randomKey*(): tuple[prv: PrivateKey, pub: PublicKey] =
    while true:
      try:
        let prv = cryptSeed(32).PrivateKey
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
  import ../zenyjs
  import ../zenyjs/core
  import ../zenyjs/address
  import ../zenyjs/config

  networks:
    bitcoin:
      pubKeyPrefix: 0'u8
      scriptPrefix: 5'u8
      wif: 128'u8
      bech32: "bc"

  zenyjs.ready:
    var pair = randomKey()
    echo pair
    echo bitcoin.getAddress(pair.pub)

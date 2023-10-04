# Copyright (c) 2023 zenywallet

when (compiles do: import zenyjs):
  import zenyjs
  import zenyjs/core
  import zenyjs/random
  import zenyjs/eckey
  import zenyjs/address
  import zenyjs/config
else:
  import ../src/zenyjs
  import ../src/zenyjs/core
  import ../src/zenyjs/random
  import ../src/zenyjs/eckey
  import ../src/zenyjs/address
  import ../src/zenyjs/config

networksDefault()

zenyjs.ready:
  let pair = randomKey()
  echo "prv: ", pair.prv
  echo "pub: ", pair.pub
  echo "address: ", BitZeny_mainnet.getAddress(pair.pub)
  echo "segwit address(bech32): ", BitZeny_mainnet.getSegwitAddress(pair.pub)
  echo "wif: ", BitZeny_mainnet.wif(pair.prv)

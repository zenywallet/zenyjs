# Copyright (c) 2023 zenywallet

import zenyjs
import zenyjs/core
import zenyjs/random
import zenyjs/eckey
import zenyjs/address

networksDefault()

zenyjs.ready:
  let pair = randomKey()
  echo "prv: ", pair.prv
  echo "pub: ", pair.pub
  echo "address: ", BitZeny_mainnet.getAddress(pair.pub)
  echo "native segwit address: ", BitZeny_mainnet.getNativeSegwitAddress(pair.pub)
  echo "wif: ", BitZeny_mainnet.wif(pair.prv)

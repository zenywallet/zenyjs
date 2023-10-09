# Copyright (c) 2023 zenywallet

when (compiles do: import zenyjs):
  import zenyjs
  import zenyjs/core
  import zenyjs/address
  import zenyjs/bip32
else:
  import ../src/zenyjs
  import ../src/zenyjs/core
  import ../src/zenyjs/address
  import ../src/zenyjs/bip32

networks:
  Bitcoin_mainnet:
    pubKeyPrefix: 0'u8
    scriptPrefix: 5'u8
    wif: 128'u8
    bech32: "bc"

zenyjs.ready:
  echo "--- bip84"
  echo "mnemonic = abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
  var seed = "5eb00bbddcf069084889a8ab9155568165f5c453ccb85e70811aaed6f6da5fc19a5ac40b389cd370d086206dec8aa6c43daea6690f20ad3d8d48b2d2ce9e38e4".Hex.toBytes
  var m = bip32.master(seed, VersionPrefix.zprv, VersionPrefix.zpub)
  echo "rootpriv = ", m.xprv()
  echo "rootpub  = ", m.xpub()
  assert m.xprv() == "zprvAWgYBBk7JR8Gjrh4UJQ2uJdG1r3WNRRfURiABBE3RvMXYSrRJL62XuezvGdPvG6GFBZduosCc1YP5wixPox7zhZLfiUm8aunE96BBa4Kei5"
  assert m.xpub() == "zpub6jftahH18ngZxLmXaKw3GSZzZsszmt9WqedkyZdezFtWRFBZqsQH5hyUmb4pCEeZGmVfQuP5bedXTB8is6fTv19U1GQRyQUKQGUTzyHACMF"

  echo "\n// Account 0, root = m/84'/0'/0'"
  var m_84h_0h_0h = m.hardened(84).hardened(0).hardened(0)
  echo "xpriv = ", m_84h_0h_0h.xprv()
  echo "xpub  = ", m_84h_0h_0h.xpub()

  echo "\n// Account 0, first receiving address = m/84'/0'/0'/0/0"
  var m_84h_0h_0h_0_0 = m_84h_0h_0h.derive(0).derive(0)
  echo "privkey = ", Bitcoin_mainnet.wif(m_84h_0h_0h_0_0.prv())
  echo "pubkey  = ", m_84h_0h_0h_0_0.pub()
  echo "address = ", Bitcoin_mainnet.getSegwitAddress(m_84h_0h_0h_0_0)

  echo "\n// Account 0, second receiving address = m/84'/0'/0'/0/1"
  var m_84h_0h_0h_0_1 = m_84h_0h_0h.derive(0).derive(1)
  echo "privkey = ", Bitcoin_mainnet.wif(m_84h_0h_0h_0_1.prv())
  echo "pubkey  = ", m_84h_0h_0h_0_1.pub()
  echo "address = ", Bitcoin_mainnet.getSegwitAddress(m_84h_0h_0h_0_1)

  echo "\n// Account 0, first change address = m/84'/0'/0'/1/0"
  var m_84h_0h_0h_1_0 = m_84h_0h_0h.derive(1).derive(0)
  echo "privkey = ", Bitcoin_mainnet.wif(m_84h_0h_0h_1_0.prv())
  echo "pubkey  = ", m_84h_0h_0h_1_0.pub()
  echo "address = ", Bitcoin_mainnet.getSegwitAddress(m_84h_0h_0h_1_0)

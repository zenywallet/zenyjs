# Copyright (c) 2023 zenywallet

when (compiles do: import zenyjs):
  import zenyjs
  import zenyjs/core
  import zenyjs/random
  import zenyjs/base58
  import zenyjs/address
  import zenyjs/bip32
else:
  import ../src/zenyjs
  import ../src/zenyjs/core
  import ../src/zenyjs/random
  import ../src/zenyjs/base58
  import ../src/zenyjs/address
  import ../src/zenyjs/bip32

networks:
  BitZeny_mainnet:
    pubKeyPrefix: 81'u8
    scriptPrefix: 5'u8
    wif: 128'u8
    bech32: "sz"
    bech32Extra: @["bz"]
    testnet: false

  BitZeny_testnet:
    pubKeyPrefix: 111'u8
    scriptPrefix: 196'u8
    wif: 239'u8
    bech32: "tz"
    testnet: true

zenyjs.ready:
  echo "--- bip44"
  var seed = cryptSeed(64)
  echo "Seed hex: ", seed
  var seedBase58 = base58.enc(seed)
  assert seed == base58.dec(seedBase58)
  echo "Seed base58: ", seedBase58
  var m = bip32.master(seed)
  echo "Master Key"
  echo "xprv: ", m.xprv()
  echo "xpub: ", m.xpub()

  var m_44h_123h_0h = m.hardened(44).hardened(123).hardened(0)
  echo "Chain: m/44'/123'/0'"
  echo "xprv: ", m_44h_123h_0h.xprv()
  echo "xpub: ", m_44h_123h_0h.xpub()

  for i in 0..<5:
    var externalNode = m_44h_123h_0h.derive(0).derive(i.uint32)
    echo "Chain: m/44'/123'/0'/0/", i
    echo "xprv: ", externalNode.xprv()
    echo "xpub: ", externalNode.xpub()
    echo "address(", BitZeny_mainnet, "): ", BitZeny_mainnet.getAddress(externalNode)

  for i in 0..<5:
    var changeNode = m_44h_123h_0h.derive(1).derive(i.uint32)
    echo "Chain: m/44'/123'/0'/1/", i
    echo "xprv: ", changeNode.xprv()
    echo "xpub: ", changeNode.xpub()
    echo "network: ", BitZeny_mainnet
    echo "address(", BitZeny_mainnet, "): ", BitZeny_mainnet.getAddress(changeNode)

  echo "--- bip44 master xprv"
  var nodeMaster = node(m.xprv())
  echo "Master Key"
  echo "xprv: ", nodeMaster.xprv()
  echo "xpub: ", nodeMaster.xpub()

  echo "--- bip44 m/44'/123'/0' xprv"
  var nodePrv = node(m_44h_123h_0h.xprv())
  for i in 0..<5:
    var externalNode = nodePrv.derive(0).derive(i.uint32)
    echo "Chain: m/44'/123'/0'/0/", i
    echo "xprv: ", externalNode.xprv()
    echo "xpub: ", externalNode.xpub()
    echo "address(", BitZeny_mainnet, "): ", BitZeny_mainnet.getAddress(externalNode)

  for i in 0..<5:
    var changeNode = nodePrv.derive(1).derive(i.uint32)
    echo "Chain: m/44'/123'/0'/1/", i
    echo "xprv: ", changeNode.xprv()
    echo "xpub: ", changeNode.xpub()
    echo "address(", BitZeny_mainnet, "): ", BitZeny_mainnet.getAddress(changeNode)

  echo "--- bip44 m/44'/123'/0' xpub"
  var nodePub = node(m_44h_123h_0h.xpub())
  for i in 0..<5:
    var externalNode = nodePub.derive(0).derive(i.uint32)
    echo "Chain: m/44'/123'/0'/0/", i
    #echo "xprv: ", externalNode.xprv()
    echo "xpub: ", externalNode.xpub()
    echo "address(", BitZeny_mainnet, "): ", BitZeny_mainnet.getAddress(externalNode)

  for i in 0..<5:
    var changeNode = nodePub.derive(1).derive(i.uint32)
    echo "Chain: m/44'/123'/0'/1/", i
    #echo "xprv: ", changeNode.xprv()
    echo "xpub: ", changeNode.xpub()
    echo "address(", BitZeny_mainnet, "): ", BitZeny_mainnet.getAddress(changeNode)

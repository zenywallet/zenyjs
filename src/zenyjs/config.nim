# Copyright (c) 2023 zenywallet

import macros

type
  Network* = object
    pubKeyPrefix*: uint8
    scriptPrefix*: uint8
    wif*: uint8
    bech32*: string
    bech32Extra*: seq[string]
    testnet*: bool

macro networks*(networkConfig: untyped): untyped =
  var networkIdEnum = nnkEnumTy.newTree(newEmptyNode())
  var networkBracket = nnkBracket.newTree()
  for n in networkConfig:
    networkIdEnum.add(n[0])
    var networkObj = nnkObjConstr.newTree(newIdentNode("Network"))
    for c in n[1]:
      networkObj.add(nnkExprColonExpr.newTree(c[0], c[1][0]))
    networkBracket.add(networkObj)
  var NetworkId = ident("NetworkId")
  var Networks = ident("Networks")
  result = quote do:
    type `NetworkId`* {.pure.} = `networkIdEnum`
    const `Networks`* = `networkBracket`

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

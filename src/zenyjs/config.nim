# Copyright (c) 2023 zenywallet

import macros
import arraylib

type
  Network* = object
    pubKeyPrefix*: uint8
    scriptPrefix*: uint8
    wif*: uint8
    bech32*: string
    bech32Extra*: seq[string]
    testnet*: bool

  NetworkId* = int

when defined(js):
  var Networks*: seq[Network]
else:
  var Networks*: Array[Network]

var curNetworkId {.compileTime.} = 0

macro networks*(networkConfig: untyped): untyped =
  result = newStmtList()
  for n in networkConfig:
    var networkId = n[0]
    var networkObj = nnkObjConstr.newTree(newIdentNode("Network"))
    for c in n[1]:
      networkObj.add(nnkExprColonExpr.newTree(c[0], c[1][0]))
    var Networks = ident("Networks")
    result.add quote do:
      when not defined(emscripten):
        const `networkId`* = `curNetworkId`.NetworkId
      `Networks`.add(`networkObj`)
    inc(curNetworkId)

when not declared(emscripten):
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

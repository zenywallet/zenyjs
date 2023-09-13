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

var Networks*: Array[Network]

var curNetworkId {.compileTime.} = 0

macro networks*(networkConfig: untyped): untyped =
  var networkStmt = newStmtList()
  for n in networkConfig:
    var networkId = n[0]
    networkStmt.add quote do:
      const `networkId`* = `curNetworkId`.NetworkId
    inc(curNetworkId)
    var networkObj = nnkObjConstr.newTree(newIdentNode("Network"))
    for c in n[1]:
      networkObj.add(nnkExprColonExpr.newTree(c[0], c[1][0]))
    var Networks = ident("Networks")
    networkStmt.add quote do:
      `Networks`.add(`networkObj`)
  result = networkStmt

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

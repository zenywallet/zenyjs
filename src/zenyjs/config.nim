# Copyright (c) 2023 zenywallet

import macros
import arraylib

type
  Network* = object
    name: string
    pubKeyPrefix*: uint8
    scriptPrefix*: uint8
    wif*: uint8
    bech32*: string
    bech32Extra*: seq[string]
    testnet*: bool

  NetworkId* = distinct int

  NetworkError* = object of CatchableError

when defined(js):
  var networkList*: seq[Network]
else:
  var networkList*: Array[Network]

var curNetworkId {.compileTime.} = 0

macro networks*(networkConfig: untyped): untyped =
  result = newStmtList()
  for n in networkConfig:
    var networkId = n[0]
    var networkObj = nnkObjConstr.newTree(newIdentNode("Network"))
    networkObj.add(nnkExprColonExpr.newTree(newIdentNode("name"), newLit($networkId)))
    for c in n[1]:
      networkObj.add(nnkExprColonExpr.newTree(c[0], c[1][0]))
    var networkList = ident("networkList")
    result.add quote do:
      when not defined(emscripten):
        const `networkId`* = `curNetworkId`.NetworkId
      `networkList`.add(`networkObj`)
    inc(curNetworkId)

template name*(nid: NetworkId): string = networkList[nid.int].name

proc `$`*(nid: NetworkId): string = nid.name

when not declared(emscripten):
  template networksDefault*() =
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

when defined(js):
  import std/json
  import std/jsffi
  import jslib except Array

  var ConfigMod = JsObject{}
  var Module: JsObject

  proc setNetworks*(networks: seq[Network]) =
    withStack:
      var networksString = cstring($(%networks))
      var networksStringUint8Array = strToUint8Array(networksString)
      var p = Module.stackAlloc(networksStringUint8Array.length.to(int) + 1)
      Module.HEAPU8.set(networksStringUint8Array, p)
      Module.HEAPU8[p.to(int) + networksStringUint8Array.length.to(int)] = 0
      ConfigMod.setNetworks(p)

  proc init*(module: JsObject) =
    Module = module
    ConfigMod.setNetworks = Module.cwrap("setNetworks", jsNull, [NumVar])
    setNetworks(networkList)

elif defined(emscripten):
  const EXPORTED_FUNCTIONS* = ["_setNetworks"]

  import std/json

  proc to[T](node: JsonNode; t: typedesc[Array[T]]): Array[T] =
    for n in node:
      result.add(n.to(T))

  proc setNetworks(networksString: cstring) {.exportc: "setNetworks".} =
    try:
      var networksJson = parseJson($networksString) # requires nim >= 2.0
      networkList.clear()
      networkList = networksJson.to(Array[Network])
    except Exception as e:
      echo e.name, ": ", e.msg
      echo e.getStackTrace()

# Copyright (c) 2023 zenywallet

type
  Network* = object
    pubKeyPrefix*: uint8
    scriptPrefix*: uint8
    wif*: uint8
    bech32*: string
    bech32Extra*: seq[string]
    testnet*: bool

  NetworkId* {.pure.} = enum
    BitZeny_mainnet
    BitZeny_testnet

const Networks* = [
  Network(
    pubKeyPrefix: 81'u8,
    scriptPrefix: 5'u8,
    wif: 128'u8,
    bech32: "sz",
    bech32Extra: @["bz"],
    testnet: false),
  Network(
    pubKeyPrefix: 111'u8,
    scriptPrefix: 196'u8,
    wif: 239'u8,
    bech32: "tz",
    testnet: true)]

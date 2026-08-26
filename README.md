# ZenyJS
A web wallet library for BitZeny

## Features
- Libraries for wallets and block explorers of the coins forked from Bitcoin. For example, block, address, transaction, sign, secp256k1, ecdh, bip32, bip39, bip44, bip47, bip49, bip84, base58, seed, uint64(for coin amounts), levenshtein, lock
- Wasm is used as the backend for JavaScript processing in the web browsers, so it is very fast
- ZenyJS is used by the [Nim](https://nim-lang.org/) language instead of JavaScript or its common transpiles like TypeScript. By using Nim, strict types, true function overloading, and more are available. See details [Nim for TypeScript Programmers](https://github.com/nim-lang/Nim/wiki/Nim-for-TypeScript-Programmers#comparison). In addition, no need to write free functions to release resources after calling Wasm-based library functions, which are automatically freed by Nim's memory management
- ZenyJS allows the same Nim code to be used in both web browsers and native executables
- Web miner and native miner, both are multi-threaded processing - [yespower](https://www.openwall.com/yespower/) only  
  This feature is moving to [zenyminer](https://github.com/zenywallet/zenyminer)
- Multi-threaded signing process for transactions in the web browsers and native executables
- Web-based QR code and barcode reader using [ZBar](https://github.com/mchehab/zbar)
- [TOTP](https://en.wikipedia.org/wiki/Time-based_one-time_password) (Time-Based One-Time Password), [RFC 6238](https://datatracker.ietf.org/doc/html/rfc6238), Compatible with [Google Authenticator](https://en.wikipedia.org/wiki/Google_Authenticator)
- Stream encryption framework for client-server communication using WebSocket
    - [Ed25519](https://github.com/orlp/ed25519) [ECDH](https://en.wikipedia.org/wiki/Elliptic-curve_Diffie%E2%80%93Hellman) key exchange
    - [Serpent](https://www.cl.cam.ac.uk/~rja14/serpent.html) encryption with [CTR](https://en.wikipedia.org/wiki/Block_cipher_mode_of_operation#Counter_(CTR)) mode
    - [LZ4](https://github.com/lz4/lz4) extremely fast compression
- Embeded [Emscripten](https://emscripten.org/) environment for building Wasm  
  This feature has now been moved to [emsdkenv](https://github.com/zenywallet/emsdkenv)
- JavaScript minifier included using google [Closure Compiler](https://developers.google.com/closure/compiler)
- Build on your device from source code, this repository does not include binary modules like *wasm*
- Very few dependencies with external modules, reducing the risk of attack code contamination by external module package developers, so-called supply chain attacks. Well, compared to Node.js
- Languages - Nim 100.0%

## Requirements
    sudo apt install build-essential automake libtool autopoint pkg-config openjdk-25-jre-headless maven
- [Nim](https://nim-lang.org/)
- [Regex](https://github.com/nitely/nim-regex)
- [emsdkenv - Emscripten SDK environment selector](https://github.com/zenywallet/emsdkenv)

## Install
    nimble install https://github.com/zenywallet/zenyjs

Or

    git clone https://github.com/zenywallet/zenyjs
    cd zenyjs
    nimble install --verbose

## Update
    git pull
    nimble uninstall zenyjs --inclDeps --verbose
    nimble depsAll
    nimble zenyjs
    nimble install --verbose

## Quick Trial
*sample.nim*
```nim
import zenyjs
import zenyjs/core
import zenyjs/random
import zenyjs/eckey
import zenyjs/address

networksDefault()

zenyjs.ready:
  var pair = randomKey()
  echo "prv: ", pair.prv
  echo "pub: ", pair.pub
  echo "address: ", BitZeny_mainnet.getAddress(pair.pub)
  echo "native segwit address: ", BitZeny_mainnet.getNativeSegwitAddress(pair.pub)
  echo "wif: ", BitZeny_mainnet.wif(pair.prv)
```

### Build and launch
#### Run native executable
    nim c -r -d:release sample.nim

#### Run in Node.js (JavaScript + Wasm)
    nim js -r -d:release sample.nim

*sample.js* and *zenyjs.wasm* will be created in the output folder. To run this, NodeJS is required. If you don't mind the version, since NodeJS is included in the *emsdkenv*, just run *emsdkenv* in the shell before execution.

Or

*buildSample.nim*
```nim
import zenyjs
import zenyjs/contents

const SampleJs = staticScript:
  include sample

const App = staticZenyJs(SampleJs)

writeFile("sample.js", App.js)
writeFile("zenyjs.wasm", App.wasm)
```

    nim c -r buildSample.nim
    node sample.js

*sample.js* and *zenyjs.wasm* are output, and *sample.js* is minified.

#### Run in web browser using Caprese web server (JavaScript + Wasm)
*server.nim*
```nim
import caprese
import zenyjs

const SampleJs = staticScript:
  include sample

const App = staticZenyJs(SampleJs)

const Css = keepIndent """
body {
  background-color: #414b52;
  color: #cfdae3;
}
"""

const SampleHtml = staticHtmlDocument:
  buildHtml(html):
    head:
      meta(charset="utf-8")
      title: text "ZenyJS Sample"
      link(rel="icon", href="data:,")
      style: verbatim Css
      script(src="/js/app.js")
    body:
      tdiv: text "ZenyJS Sample"

server(ssl = true, ip = "127.0.0.1", port = 8009):
  routes(host = "localhost"):
    get "/": SampleHtml.content("html").response
    get "/js/app.js": App.js.content("js").response
    get "/js/zenyjs.wasm": App.wasm.content("wasm").response
    "Not found".addHeader(Status404).send
```

    nim c -r -d:release --threads:on --mm:orc server.nim

Open [https://localhost:8009/](https://localhost:8009/) in your browser and open the debug console.

### Troubleshooting
> *Somehow wasm is not working on web browser*

Try using Nim version >= 2.0.0  
ZenyJS needs to be reinstalled.

> *Error: cannot open file: caprese*

    sudo apt install build-essential automake autoconf libtool cmake default-jre-headless maven
    nimble install https://github.com/zenywallet/caprese

> *Error: internal error: ("genAddr: 2", skTemp)*  
> *Error: nim js failed*

This issue has been fixed in Nim version 2.2.10

Workaround for earlier versions:
```sh
$ choosenim show
  Selected: 1.6.14
   Channel: stable
      Path: /home/<username>/.choosenim/toolchains/nim-1.6.14

  Versions:
            ...

$ cd /home/<username>/.choosenim/toolchains/nim-1.6.14
```

Edit *compiler/jsgen.nim*, add `skTemp` of the case.
```diff
@@ proc genSymAddr(p: PProc, n: PNode, typ: PType, r: var TCompRes) =
     r.res = s.loc.r
     r.address = nil
     r.typ = etyNone
-  of skVar, skLet, skResult:
+  of skVar, skLet, skResult, skTemp:
     r.kind = resExpr
     let jsType = mapType(p):
       if typ.isNil:
```

If you cannot find `genSymAddr`, search `genAddr` and add `skTemp` of the case.
```diff
@@ proc genAddr(p: PProc, n: PNode, r: var TCompRes) =
       r.res = s.loc.r
       r.address = nil
       r.typ = etyNone
-    of skVar, skLet, skResult:
+    of skVar, skLet, skResult, skTemp:
       r.kind = resExpr
       let jsType = mapType(p, n.typ)
       if jsType == etyObject:
```

```sh
cp -a bin/nim bin/nim.bak
nim c koch.nim
./koch boot -d:release
```
See [Bootstrapping the compiler](https://nim-lang.github.io/Nim/intern.html#bootstrapping-the-compiler) for detail.

> *Error: attempting to call undeclared routine: 'realloc'*

    import zenyjs/core

> *TypeError: Cannot read properties of null (reading 'malloc')*
```nim
import zenyjs

zenyjs.ready:
  ...
```

## Custom Coin Networks
Set the coin parameters in the `networks:` block.

```nim
import zenyjs
import zenyjs/core
import zenyjs/random
import zenyjs/address

networks:
  bitcoin:
    pubKeyPrefix: 0'u8
    scriptPrefix: 5'u8
    wif: 128'u8
    bech32: "bc"

  bitzeny:
    pubKeyPrefix: 81'u8
    scriptPrefix: 5'u8
    wif: 128'u8
    bech32: "sz"

zenyjs.ready:
  var pair = randomKey()
  echo "Bitcoin address: ", bitcoin.getAddress(pair.pub)
  echo "BitZeny address: ", bitzeny.getAddress(pair.pub)
```

## BIP32, BIP44
```nim
import zenyjs
import zenyjs/core
import zenyjs/random
import zenyjs/address
import zenyjs/bip32

networksDefault()

zenyjs.ready:
  var seed = cryptSeed(64)
  var m = bip32.master(seed)
  var n = m.hardened(44).hardened(123).hardened(0)
  echo "xprv: ", n.xprv()
  echo "xpub: ", n.xpub()
  for i in 0..2:
    var external = n.derive(0).derive(i.uint32)
    echo "m/44'/123'/0'/0/", i, " ", BitZeny_mainnet.getAddress(external)
  for i in 0..2:
    var internal = n.derive(1).derive(i.uint32)
    echo "m/44'/123'/0'/1/", i, " ", BitZeny_mainnet.getAddress(internal)
```

Import from keys
```nim
  var n = bip32.node("xprv9x ... ")
  echo n.xprv()
  echo n.xpub()
```
```nim
  var n = bip32.node("xpub6B ... ")
  #echo n.xprv()
  echo n.xpub()
```

## BIP39
```nim
import zenyjs
import zenyjs/core
import zenyjs/seed
import zenyjs/bip39
import zenyjs/bip39_en

const en = bip39_en.words

zenyjs.ready:
  var entropy = cryptSeed(32)
  var mnemonic = entropyToMnemonic(entropy, en)
  var bip39Seed = mnemonicToSeed(normalizeMnemonic(mnemonic), passphrase = "")
  echo "entropy: ", entropy
  echo "mnemonic: ", plainMnemonic(mnemonic)
  echo "bip39 seed: ", bip39Seed

  assert entropy == mnemonicToEntropy(mnemonic, en)
```

## Create and sign a transaction
```nim
import std/json
import zenyjs
import zenyjs/core
import zenyjs/tx as txlib
import zenyjs/address
import zenyjs/utils
import zenyjs/eckey

networksDefault()

zenyjs.ready:
  var txid0 = Hash(Hex("f347f3898ac1368463767cce59f359c83eaa1c32c0321e1f1aeaeaf52a4edaeb"))
  var n0 = 0'u32
  var txid1 = Hash(Hex("35645a2cb6b7270efda4cd69f6d69ec33b6eed6db5320fe7411c020dff6d7534"))
  var n1 = 0'u32
  var inputScript0 = BitZeny_mainnet.getScript("ZqWp638LJVdiFkHGGLD5jh8sQnPQbWcMco")
  var inputScript1 = BitZeny_mainnet.getScript("ZherrACZpqr6wtVq6u52DjgWw3nc8roVLR")
  var outputScript0 = BitZeny_mainnet.getScript("ZqBb6zr8P7ijKZsGfv4MihGbuLYNsFgHCF")
  var outputScript1 = BitZeny_mainnet.getScript("ZqDF1JhpkoK8zjNxYozYHCuy7rafhiFFga")
  var prv0 = PrivateKey(Hex("7008e08494e78a4576595c08372ef08ff3c5a5fb669d04ab688af5ec05d4e419"))
  var prv1 = PrivateKey(Hex("b416f75b5dc0679154c6d1d8fd0932816eaee59782d8f67fb3465ca0662f267b"))
  var emptySig: Sig

  var tx = newTx()
  tx.ver = 2'i32
  tx.ins.add (tx: txid0, n: n0, sig: emptySig, sequence: 0xffffffff'u32)
  tx.ins.add (tx: txid1, n: n1, sig: emptySig, sequence: 0xffffffff'u32)
  tx.outs.add (value: 39390000'u64, script: outputScript0)
  tx.outs.add (value: 610000'u64 - 372'u64, script: outputScript1)

  tx.ins[0].sig = inputScript0.Sig
  var txSignHash0 = sha256d((tx, SIGHASH_ALL.uint32).toBytes)
  tx.ins[0].sig = emptySig
  tx.ins[1].sig = inputScript1.Sig
  var txSignHash1 = sha256d((tx, SIGHASH_ALL.uint32).toBytes)

  var signDer0 = sign(prv0, txSignHash0)
  var sig0 = Sig(PushData(signDer0, SIGHASH_ALL.uint8), PushData(prv0.pub))
  tx.ins[0].sig = sig0
  var signDer1 = sign(prv1, txSignHash1)
  var sig1 = Sig(PushData(signDer1, SIGHASH_ALL.uint8), PushData(prv1.pub))
  tx.ins[1].sig = sig1

  echo (%tx).pretty
  echo tx.toBytes
```

## TOTP (Time-based One-Time Password)
```nim
import std/times
import zenyjs
import zenyjs/base32

zenyjs.ready:
  var t = newTotp(base32.dec("testtesttesttest")) # 6, 30, SHA1
  echo t.generate(epochTime().uint64)
```

## License
MIT

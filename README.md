# ZenyJS
A web wallet library for BitZeny

## Features
- Libraries for wallets and block explorers of the coins forked from Bitcoin. For example, block, address, transaction, sign, secp256k1, ecdh, bip32, bip44, bip49, bip84, bip47, base58, seed, uint64(for coin amounts), levenshtein, lock
- Wasm is used as the backend for JavaScript processing in the web browsers, so it is very fast
- ZenyJS is used by the [Nim](https://nim-lang.org/) language instead of JavaScript or its common transpiles like TypeScript. By using Nim, strict types, true function overloading, and more are available. See details [Nim for TypeScript Programmers](https://github.com/nim-lang/Nim/wiki/Nim-for-TypeScript-Programmers#comparison). In addition, no need to write free functions to release resources after calling Wasm-based library functions, which are automatically freed by Nim's memory management
- ZenyJS allows the same Nim code to be used in both web browsers and native executables
- Web miner and native miner, both are multi-threaded processing. [yespower](https://www.openwall.com/yespower/) only
- Multi-threaded signing process for transactions in the web browsers and native executables
- Web-based QR code and barcode reader using [ZBar](https://github.com/mchehab/zbar)
- [TOTP](https://en.wikipedia.org/wiki/Time-based_one-time_password) (Time-Based One-Time Password), [RFC 6238](https://datatracker.ietf.org/doc/html/rfc6238), Compatible with [Google Authenticator](https://en.wikipedia.org/wiki/Google_Authenticator)
- Stream encryption framework for client-server communication using WebSocket
    - [Ed25519](https://github.com/orlp/ed25519) [ECDH](https://en.wikipedia.org/wiki/Elliptic-curve_Diffie%E2%80%93Hellman) key exchange
    - [Serpent](https://www.cl.cam.ac.uk/~rja14/serpent.html) encryption with [CTR](https://en.wikipedia.org/wiki/Block_cipher_mode_of_operation#Counter_(CTR)) mode
    - [LZ4](https://github.com/lz4/lz4) extremely fast compression
- Embeded [Emscripten](https://emscripten.org/) environment for building Wasm
- JavaScript minifier included using google [Closure Compiler](https://developers.google.com/closure/compiler)
- Build on your device from source code, this repository does not include binary modules like *wasm*
- Very few dependencies with external modules, reducing the risk of attack code contamination by external module package developers. Well, compared to Node.js
- Languages - Nim 100.0%

## Requirements
Nim must be installed.

    sudo apt install build-essential automake libtool autopoint openjdk-19-jre maven

## Install
    nimble install https://github.com/zenywallet/zenyjs

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
  echo "segwit address(bech32): ", BitZeny_mainnet.getSegwitAddress(pair.pub)
  echo "wif: ", BitZeny_mainnet.wif(pair.prv)
```

### Build and launch
#### Run native executable
    nim c -r -d:release sample.nim

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
    get "/": return SampleHtml.content("html").response
    get "/js/app.js": return App.js.content("js").response
    get "/js/zenyjs.wasm": return App.wasm.content("wasm").response
    return "Not found".addHeader(Status404).send

serverStart()
```

    nim c -r -d:release --threads:on --mm:orc server.nim

Open [https://localhost:8009/](https://localhost:8009/) in your browser and open the debug console.

#### Run in Node.js (JavaScript + Wasm)
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

### Troubleshooting
> *Somehow wasm is not working on web browser*

Try using Nim version >= 2.0.0  
ZenyJS needs to be reinstalled.

> *Error: cannot open file: caprese*

    sudo apt install build-essential autoconf libtool cmake pkg-config golang openjdk-19-jre maven
    nimble install https://github.com/zenywallet/caprese

> *Error: internal error: ("genAddr: 2", skTemp)*  
> *Error: nim js failed*
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
$ cp -a bin/nim bin/nim.bak
$ nim c koch.nim
$ ./koch boot -d:release
```
See [Bootstrapping the compiler](https://nim-lang.github.io/Nim/intern.html#bootstrapping-the-compiler) for detail.

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

## License
MIT

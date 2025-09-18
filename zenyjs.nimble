# Package

version       = "0.1.0"
author        = "zenywallet"
description   = "A web wallet library for BitZeny"
license       = "MIT"
srcDir        = "src"


# Dependencies

requires "nim >= 1.6.4"
requires "regex"


import std/os

template emsdkEnv(cmd: string): string =
  let emsdkDir = currentSourcePath().parentDir() / "deps/emsdk"
  let curDir = getCurrentDir()
  "cd " & emsdkDir & " && . ./emsdk_env.sh && cd " & curDir & " && " & cmd

task emsdk, "Emscripten SDK install":
  withDir "deps/emsdk":
    exec "git pull origin main"
    exec "./emsdk install 3.1.74"
    exec "./emsdk activate 3.1.74"
    exec ". ./emsdk_env.sh" # For testing, does not effect the current terminal

task emsdkLatest, "Emscripten SDK install":
  withDir "deps/emsdk":
    exec "git pull origin main"
    exec "./emsdk install latest"
    exec "./emsdk activate latest"
    exec ". ./emsdk_env.sh" # For testing, does not effect the current terminal

task secp256k1, "make secp256k1":
  withDir "deps/secp256k1":
    exec "./autogen.sh"
    exec "./configure --enable-module-ecdh --disable-shared --enable-static --disable-tests --disable-benchmark --disable-openssl-tests --disable-exhaustive-tests"
    exec "make -j$(nproc --all || sysctl -n hw.ncpu || getconf _NPROCESSORS_ONLN || echo 1)"
    exec "mkdir -p ../../src/zenyjs/deps/secp256k1/libs"
    exec "cp .libs/libsecp256k1.a ../../src/zenyjs/deps/secp256k1/libs/"

task wasmSecp256k1, "make wasm-secp256k1":
  withDir "deps/wasm-secp256k1":
    exec "./autogen.sh"
    exec emsdkEnv("emconfigure ./configure --enable-module-ecdh --disable-shared --enable-static --disable-tests --disable-benchmark --disable-openssl-tests --disable-exhaustive-tests")
    exec emsdkEnv("emmake make -j$(nproc --all || sysctl -n hw.ncpu || getconf _NPROCESSORS_ONLN || echo 1)")
    exec "mkdir -p ../../src/zenyjs/deps/wasm-secp256k1/libs"
    exec "cp .libs/libsecp256k1.a ../../src/zenyjs/deps/wasm-secp256k1/libs/"

task zbar, "make zbar":
  withDir "deps/zbar":
    exec "sed -i \"s/ -Werror//\" $(pwd)/configure.ac"
    exec "autoreconf -vfi"
    exec emsdkEnv("emconfigure ./configure CPPFLAGS=-DNDEBUG=1 --without-x --without-jpeg --without-imagemagick --without-npapi --without-gtk --without-python --without-qt --without-xshm --disable-video --disable-pthread --enable-codes=all")
    exec emsdkEnv("emmake make -j$(nproc --all || sysctl -n hw.ncpu || getconf _NPROCESSORS_ONLN || echo 1)")

task jsLevenshtein, "copy js-levenshtein":
  withDir "src/zenyjs":
    exec "mkdir -p deps/js-levenshtein"
    exec "cp ../../deps/js-levenshtein/index.js deps/js-levenshtein/"

task jsCuint, "copy js-cuint":
  withDir "src/zenyjs":
    exec "mkdir -p deps/js-cuint/lib"
    exec "cp ../../deps/js-cuint/lib/uint64.js deps/js-cuint/lib/"

task bech32, "copy segwit_addr.c":
  withDir "deps/bech32":
    exec "mkdir -p ../../src/zenyjs/deps/bech32/ref/c"
    exec "cp ref/c/segwit_addr.c ../../src/zenyjs/deps/bech32/ref/c/"
    exec "cp ref/c/segwit_addr.h ../../src/zenyjs/deps/bech32/ref/c/"

task bearssl, "copy bearssl":
  withDir "deps/bearssl":
    exec "mkdir -p ../../src/bearssl"
    exec "cp -r inc src ../../src/bearssl/"

task ripemd160, "copy ripemd-160":
  withDir "deps/ripemd-160":
    exec "mkdir -p ../../src/ripemd-160"
    exec "cp -r . ../../src/ripemd-160/"

task yespower, "copy yespower":
  withDir "deps/yespower":
    exec "mkdir -p ../../src/yespower"
    exec "cp -r . ../../src/yespower/"

task lz4, "copy lz4":
  withDir "deps/lz4":
    exec "mkdir -p ../../src/lz4"
    exec "cp -r lib ../../src/lz4/"

task depsAll, "Build deps":
  exec "git submodule update --init"
  exec "git submodule update --remote deps/emsdk"
  emsdkTask()
  secp256k1Task()
  wasmSecp256k1Task()
  zbarTask()
  jsLevenshteinTask()
  jsCuintTask()
  bech32Task()
  bearsslTask()
  ripemd160Task()
  yespowerTask()
  lz4Task()

task zenyjs, "Build zenyjs":
  withDir "src/zenyjs":
    exec emsdkEnv("nim c -d:release --threads:off -d:emscripten --noMain:on --gc:orc --forceBuild:on -o:zenyjs.js zenyjs.nim")
    exec "nim c -r zenyjs_patch.nim && rm zenyjs_patch"

task zenyjsdebug, "Build zenyjs debug":
  withDir "src/zenyjs":
    exec emsdkEnv("nim c --threads:off -d:emscripten --noMain:on --gc:orc --forceBuild:on -o:zenyjs.js zenyjs.nim")
    exec "nim c -r zenyjs_patch.nim && rm zenyjs_patch"

before install:
  if not fileExists("src/zenyjs/zenyjs.wasm"):
    depsAllTask()
    zenyjsTask()

# Package

version       = "0.1.0"
author        = "zenywallet"
description   = "A web wallet library for BitZeny"
license       = "MIT"
srcDir        = "src"


# Dependencies

requires "nim >= 1.6.4"
requires "nimcrypto"
requires "templates"


import std/os

template emsdkEnv(cmd: string): string =
  let emsdkDir = currentSourcePath().parentDir() / "deps/emsdk"
  let curDir = getCurrentDir()
  "cd " & emsdkDir & " && . ./emsdk_env.sh && cd " & curDir & " && " & cmd

task emsdk, "Emscripten SDK install":
  withDir "deps/emsdk":
    exec "git pull origin main"
    exec "./emsdk install latest"
    exec "./emsdk activate latest"
    exec ". ./emsdk_env.sh" # For testing, does not effect the current terminal

task secp256k1, "make secp256k1":
  withDir "deps/secp256k1":
    exec "./autogen.sh"
    exec "./configure --enable-module-ecdh --disable-shared --enable-static --disable-tests --disable-benchmark --disable-openssl-tests --disable-exhaustive-tests"
    exec "make -j$(nproc)"

task wasmSecp256k1, "make wasm-secp256k1":
  withDir "deps/wasm-secp256k1":
    exec "./autogen.sh"
    exec emsdkEnv("emconfigure ./configure --enable-module-ecdh --disable-shared --enable-static --disable-tests --disable-benchmark --disable-openssl-tests --disable-exhaustive-tests")
    exec emsdkEnv("emmake make -j$(nproc)")

task zbar, "make zbar":
  withDir "deps/zbar":
    exec "sed -i \"s/ -Werror//\" $(pwd)/configure.ac"
    exec "autoreconf -vfi"
    exec emsdkEnv("emconfigure ./configure CPPFLAGS=-DNDEBUG=1 --without-x --without-jpeg --without-imagemagick --without-npapi --without-gtk --without-python --without-qt --without-xshm --disable-video --disable-pthread --enable-codes=all")
    exec emsdkEnv("emmake make -j$(nproc)")

task jsLevenshtein, "copy js-levenshtein":
  withDir "src/zenyjs":
    exec "mkdir -p deps/js-levenshtein"
    exec "cp ../../deps/js-levenshtein/index.js deps/js-levenshtein/"

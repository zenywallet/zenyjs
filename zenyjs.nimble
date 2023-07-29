# Package

version       = "0.1.0"
author        = "zenywallet"
description   = "A web wallet library for BitZeny"
license       = "MIT"
srcDir        = "src"


# Dependencies

requires "nim >= 1.6.4"


import std/os

template emsdkEnv(cmd: string): string =
  let emsdkDir = currentSourcePath().parentDir() / "deps/emsdk"
  let curDir = getCurrentDir()
  "cd " & emsdkDir & " && . ./emsdk_env.sh && cd " & curDir & " && " & cmd

task emsdk, "Emscripten SDK install":
  withDir "deps/emsdk":
    exec "git pull"
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
    exec emsdkEnv("emconfigure ./configure")
    exec emsdkEnv("emmake make -j$(nproc)")

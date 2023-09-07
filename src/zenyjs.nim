# Copyright (c) 2023 zenywallet

when defined(js):
  import zenyjs/zenyjs
  export zenyjs

else:
  import std/os
  import zenyjs/contents
  import zenyjs/zenyjs_externs

  const ZenyWasm = staticRead(currentSourcePath().parentDir() / "zenyjs/zenyjs.wasm")

  proc staticZenyJs*(src: static string): tuple[js: string, wasm: string] {.compileTime.} =
    let minJs = scriptMinifier(src, extern = ZenyJsExterns)
    (js: minJs, wasm: ZenyWasm)

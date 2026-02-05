# Copyright (c) 2023 zenywallet

{.used.}

when defined(js):
  import zenyjs/zenyjs
  export zenyjs

  import std/os
  import std/compilesettings
  const ZenyWasm = staticRead(currentSourcePath().parentDir() / "zenyjs/zenyjs.wasm")
  macro writeWasm() =
    var outputDir = querySetting(outDir)
    writeFile(outputDir / "zenyjs.wasm", ZenyWasm)
  writeWasm()

elif defined(emscripten):
  import zenyjs/zenyjs
  export zenyjs

else:
  import std/os
  import zenyjs/zenyjs
  import zenyjs/contents
  import zenyjs/zenyjs_externs
  export zenyjs

  const ZenyWasm* = staticRead(currentSourcePath().parentDir() / "zenyjs/zenyjs.wasm")

  proc staticZenyJs*(src: static string, minify: bool = true): tuple[js: string, wasm: string] {.compileTime.} =
    if minify:
      let minJs = contents.scriptMinifier(src, extern = ZenyJsExterns)
      (js: minJs, wasm: ZenyWasm)
    else:
      (js: src, wasm: ZenyWasm)

  proc staticZenyJs*(src, extern: static string): tuple[js: string, wasm: string] {.compileTime.} =
    let minJs = contents.scriptMinifier(src, extern = extern & "\n" & ZenyJsExterns)
    (js: minJs, wasm: ZenyWasm)

  proc staticZenyJs*(src: static string, extern: static seq[string]): tuple[js: string, wasm: string] {.compileTime.} =
    let minJs = contents.scriptMinifier(src, extern = generateExternCode(extern) & "\n" & ZenyJsExterns)
    (js: minJs, wasm: ZenyWasm)

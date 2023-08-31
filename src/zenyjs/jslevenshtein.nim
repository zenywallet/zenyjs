# Copyright (c) 2022 zenywallet

import jsffi
import os

{.emit: """
var levenshteinModule = {};
(function(module) {
""" & staticRead(currentSourcePath().parentDir() / "deps/js-levenshtein/index.js") & """
})(levenshteinModule);
""".}

var levenshteinModule {.importc, nodecl.}: JsObject
var Module = JsObject{levenshtein: levenshteinModule.exports}

proc levenshtein*(a, b: cstring): int = Module.levenshtein(a, b).to(int)


when isMainModule:
  echo levenshtein("kitten", "sitting")

# Copyright (c) 2023 zenywallet

when (compiles do: import zenyjs):
  import zenyjs
  import zenyjs/contents
else:
  import ../src/zenyjs
  import ../src/zenyjs/contents

const SampleJs = staticScript:
  include sample

const App = staticZenyJs(SampleJs)

writeFile("sample.js", App.js)
writeFile("zenyjs.wasm", App.wasm)

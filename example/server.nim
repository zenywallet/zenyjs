# Copyright (c) 2023 zenywallet

import caprese
when (compiles do: import zenyjs):
  import zenyjs
else:
  import ../src/zenyjs

config:
  sslLib = BearSSL

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
      pre(id="debug")

server(ssl = true, ip = "127.0.0.1", port = 8009):
  routes(host = "localhost"):
    get "/":
      return response(content(SampleHtml, "html"))

    get "/js/app.js":
      return response(content(App.js, "js"))

    get "/js/zenyjs.wasm":
      return response(content(App.wasm, "wasm"))

    return send("Not found".addHeader(Status404))

serverStart()

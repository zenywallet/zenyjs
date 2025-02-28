# Copyright (c) 2021 zenywallet

import std/macros
import std/os
import exec

template staticScript*(body: untyped): string =
  block:
    const srcFile = instantiationInfo(-1, true).filename
    const srcFileDir = splitFile(srcFile).dir

    macro staticScriptMacro(bodyMacro: untyped): string =
      return nnkStmtList.newTree(
        newLit(compileJsCode(srcFileDir, $bodyMacro.toStrLit))
      )
    staticScriptMacro: body

template scriptMinifier*(code, extern: string): string =
  block:
    const srcFile = instantiationInfo(-1, true).filename
    const srcFileDir = splitFile(srcFile).dir

    macro scriptMinifierMacro(): string =
      return nnkStmtList.newTree(
        newLit(minifyJsCode(srcFileDir, code, extern))
      )
    scriptMinifierMacro()

var externKeywordId {.compileTime.}: int

proc generateExternCode*(externKeyword: seq[string]): string {.compileTime.} =
  inc(externKeywordId)
  result = "var externKeyword" & $externKeywordId & " = {\n"
  for i, s in externKeyword:
    if s.len == 0:
      error "scriptMinifier extern keyword length = 0"
    if i == externKeyword.len - 1:
      result.add("  " & s & ": 0\n")
    else:
      result.add("  " & s & ": 0,\n")
  result.add("};\n")

template scriptMinifier*(code: string, extern: seq[string]): string =
  block:
    const srcFile = instantiationInfo(-1, true).filename
    const srcFileDir = splitFile(srcFile).dir
    const externCode = generateExternCode(extern)

    macro scriptMinifierMacro(): string =
      return nnkStmtList.newTree(
        newLit(minifyJsCode(srcFileDir, code, externCode))
      )
    scriptMinifierMacro()

when defined(SANITIZEHTML_COMPACT):
  proc sanitizeHtml*(s: string): string =
    for c in s:
      case c
      of '&': result.add("&amp;")
      of '\'': result.add("&#39;")
      of '`': result.add("&#96;")
      of '"': result.add("&quot;")
      of '<': result.add("&lt;")
      of '>': result.add("&gt;")
      of '/': result.add("&#47;")
      else: result.add(c)
else:
  const saniMap = [
    "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "",
    "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "",
    "", "", "&quot;", "", "", "", "&amp;", "&#39;", "", "", "", "", "", "", "", "&#47;",
    "", "", "", "", "", "", "", "", "", "", "", "", "&lt;", "", "&gt;", "",
    "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "",
    "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "",
    "&#96;", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "",
    "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "",
    "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "",
    "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "",
    "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "",
    "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "",
    "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "",
    "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "",
    "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "",
    "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", ""]

  {.push checks: off.}
  proc sanitizeHtml*(s: string): string =
    result = newString(s.len * 6)
    var cur = 0
    var startPos = 0
    for i, c in s:
      if saniMap[c.byte].len != 0:
        let d = i - startPos
        copyMem(addr result[cur], unsafeAddr s[startPos], d)
        inc(cur, d)
        let sLen = saniMap[c.byte].len
        copyMem(addr result[cur], unsafeAddr saniMap[c.byte][0], sLen)
        inc(cur, sLen)
        startPos = i + 1
    let d = s.len - startPos
    copyMem(addr result[cur], unsafeAddr s[startPos], d)
    result.setLen(cur + d)
  {.pop.}

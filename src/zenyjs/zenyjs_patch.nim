# Copyright (c) 2025 zenywallet

import std/os
import std/strutils
import regex

const curPath = currentSourcePath().parentDir()

var jsOrg = readFile(curPath / "zenyjs.js")

var jsPatch = jsOrg.replace(re2"""class ExitStatus\s+\{\s+name="ExitStatus";\s+constructor\(status\)\s+\{""",
  """class ExitStatus {
  constructor(status) {
    this.name = "ExitStatus";""")

writeFile(curPath / "zenyjs.js", jsPatch)

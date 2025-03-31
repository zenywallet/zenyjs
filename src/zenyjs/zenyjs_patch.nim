# Copyright (c) 2025 zenywallet

import std/os
import std/strutils
import regex

const curPath = currentSourcePath().parentDir()

var jsOrg = readFile(curPath / "zenyjs.js")

var jsPatch = jsOrg.replace(re2"""class\s+ExitStatus\s*\{\s*name\s*=\s*"ExitStatus"\s*;\s*constructor\s*\(\s*status\s*\)\s*\{""",
  """class ExitStatus {
  constructor(status) {
    this.name = "ExitStatus";""")

writeFile(curPath / "zenyjs.js", jsPatch)

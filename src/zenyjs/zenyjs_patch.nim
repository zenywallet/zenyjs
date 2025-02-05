# Copyright (c) 2025 zenywallet

import std/os
import std/strutils

const curPath = currentSourcePath().parentDir()

var jsOrg = readFile(curPath / "zenyjs.js")

var jsPatch = jsOrg.replace("""class ExitStatus {
  name="ExitStatus";
  constructor(status) {
""", """class ExitStatus {
  constructor(status) {
    this.name = "ExitStatus";
""")

writeFile(curPath / "zenyjs.js", jsPatch)

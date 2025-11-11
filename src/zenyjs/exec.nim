# Copyright (c) 2022 zenywallet

import std/os
import std/macros
import std/strformat
import std/strutils
import std/compilesettings

const srcFile = currentSourcePath()
const (srcFileDir, srcFileName, srcFileExt) = splitFile(srcFile)
const binDir = srcFileDir / "bin"
const execHelperExe = binDir / "exec_helper"
const execHelperSrc = srcFileDir / "exec_helper" & srcFileExt

macro buildExecHelper() =
  echo staticExec("nim c -o:bin/ " & execHelperSrc)
buildExecHelper()

proc randomStrCT*(): string {.compileTime.} = staticExec(execHelperExe & " randomstr")

proc rmFileCT*(filename: string) {.compileTime.} =
  echo staticExec(execHelperExe & " rmfile " & filename)

proc basicExternCT*(filename: string): string {.compileTime.} =
  staticExec(execHelperExe & " basicextern " & filename)

proc removeTmpFilesCT(removeDir: string) {.compileTime.} =
  var tmpFiles = removeDir / srcFileName & "_tmp" & "[[:digit:]]*"
  var ret = staticExec("find " & tmpFiles & " -type f -mmin +60 -print0 2> /dev/null | xargs -r0 rm")
  if ret.len > 0:
    echo ret

proc removeCacheDirsCT(removeDir: string) {.compileTime.} =
  var tmpFiles = removeDir / srcFileName & "_tmp" & "[[:digit:]]*"
  var ret = staticExec("find \"" & tmpFiles & "\" -type d -mmin +5 -print0 2> /dev/null | xargs -r0 rm -rf")
  if ret.len > 0:
    echo ret

var tmpFileIdCT {.compileTime.}: int = 0

proc staticExecCode*(srcFileDir: string, code: string, rstr: string): string {.compileTime.} =
  inc(tmpFileIdCT)
  let exeFileName = srcFileName & "_tmp" & $tmpFileIdCT & rstr
  let tmpExeFile = srcFileDir / exeFileName
  let tmpSrcFile = tmpExeFile & srcFileExt
  let cacheDir = srcFileDir / "nimcache"
  let tmpCacheDir = cacheDir / exeFileName
  writeFile(tmpSrcFile, code)
  echo staticExec("nim c --nimcache:" & tmpCacheDir & " " & tmpSrcFile)
  if not fileExists(tmpExeFile):
    rmFileCT(tmpSrcFile)
    echo staticExec("rm -rf \"" & tmpCacheDir & "\"")
    macros.error "nim c failed"
  result = staticExec("cd " & srcFileDir & " && " & tmpExeFile)
  removeTmpFilesCT(srcFileDir)
  removeCacheDirsCT(cacheDir)
  rmFileCT(tmpExeFile)
  rmFileCT(tmpSrcFile)
  echo staticExec("rm -rf \"" & tmpCacheDir & "\"")
  discard staticExec("rmdir \"" & cacheDir & "\"")

proc makeDiscardable[T](a: T): T {.discardable, inline.} = a

template staticExecCode*(code: string): string = # discardable
  block:
    const srcFile = instantiationInfo(-1, true).filename
    const srcFileDir = splitFile(srcFile).dir

    macro execCodeResult(): string =
      nnkStmtList.newTree(
        newLit(staticExecCode(srcFileDir, code, randomStrCT()))
      )
    makeDiscardable(execCodeResult())

template staticExecCode*(srcFileDir: string, code: string): string = # discardable
  makeDiscardable(staticExecCode(srcFileDir, code, randomStrCT()))

template staticExecCode*(body: untyped): string = # discardable
  block:
    const srcFile = instantiationInfo(-1, true).filename
    const srcFileDir = splitFile(srcFile).dir

    macro execCodeResult(bodyMacro: untyped): string =
      nnkStmtList.newTree(
        newLit(staticExecCode(srcFileDir, $bodyMacro.toStrLit))
      )
    makeDiscardable(execCodeResult(body))

proc removeThreadVarPatchCT(code: string): string {.compileTime.} =
  var stage = 0
  for line in splitLines(code):
    if stage == 0 and line.startsWith("if (globalThis.") and line.endsWith(" === undefined) {"):
      stage = 1
    elif stage == 1:
      result.add(line.replace("  globalThis.", "var ") & "\n")
      stage = 2
    elif stage == 2:
      stage = 0
    else:
      result.add(line & "\n")

proc staticCompileJsCode*(srcFileDir: string, code: string, rstr: string): string {.compileTime.} =
  inc(tmpFileIdCT)
  let tmpNameFile = srcFileDir / srcFileName & "_tmp" & $tmpFileIdCT & rstr
  let tmpSrcFile = tmpNameFile & srcFileExt
  let tmpJsFile = tmpNameFile & ".js"
  writeFile(tmpSrcFile, code)
  var verbosity = ""
  let cl = querySetting(SingleValueSetting.commandLine)
  var params = cl.split(" ")
  for param in params:
    if param.startsWith("--verbosity:"):
      verbosity = " " & param
      break
  echo staticExec("nim js -d:release --mm:orc" & verbosity & " -o:" & tmpJsFile & " " & tmpSrcFile)
  if not fileExists(tmpJsFile):
    rmFileCT(tmpSrcFile)
    macros.error "nim js failed"
  result = readFile(tmpJsFile)
  result = removeThreadVarPatchCT(result)
  removeTmpFilesCT(srcFileDir)
  rmFileCT(tmpJsFile)
  rmFileCT(tmpSrcFile)

template staticCompileJsCode*(baseDir, code: string): string =
  staticCompileJsCode(baseDir, code, randomStrCT())

proc staticMinifyJsCode*(srcFileDir: string, code: string, extern: string, rstr: string): string {.compileTime.} =
  inc(tmpFileIdCT)
  let tmpNameFile = srcFileDir / srcFileName & "_tmp" & $tmpFileIdCT & rstr
  let tmpSrcFile = tmpNameFile & ".js"
  let tmpExtFile = tmpNameFile & "_extern.js"
  let tmpDstFile = tmpNameFile & "_min.js"
  writeFile(tmpSrcFile, code)
  writeFile(tmpExtFile, extern & basicExternCT(tmpSrcFile))
  let downloadClosureCompiler = staticExec """
ZENYJS_CACHE_DIR=${XDG_CACHE_HOME:-"$HOME/.cache"}/zenyjs
if [ -x "$(command -v google-closure-compiler)" ]; then
  echo "download closure-compiler skip"
elif ls $ZENYJS_CACHE_DIR/closure-compiler-*.jar 1> /dev/null 2>&1; then
  echo "download closure-compiler skip"
else
  mkdir -p $ZENYJS_CACHE_DIR
  mvn dependency:get -e -Ddest=$ZENYJS_CACHE_DIR -Dartifact=com.google.javascript:closure-compiler:LATEST
fi
"""
  echo downloadClosureCompiler
  let closureCompiler = staticExec """
ZENYJS_CACHE_DIR=${XDG_CACHE_HOME:-"$HOME/.cache"}/zenyjs
if [ -x "$(command -v google-closure-compiler)" ]; then
  closure_compiler="google-closure-compiler"
elif ls $ZENYJS_CACHE_DIR/closure-compiler-*.jar 1> /dev/null 2>&1; then
  closure_compiler="java -jar $(ls $ZENYJS_CACHE_DIR/closure-compiler-*.jar | sort -r | head -n1)"
fi
echo $closure_compiler
"""
  if closureCompiler.len > 0:
    echo "closure compiler: " & closureCompiler
    let retClosure = staticExec fmt"""
  {closureCompiler} --compilation_level ADVANCED --jscomp_off=checkVars \
  --jscomp_off=checkTypes --jscomp_off=uselessCode --js_output_file="{tmpDstFile}" \
  --externs "{tmpExtFile}" "{tmpSrcFile}" 2>&1 | cut -c 1-240
  """
    if retClosure.len > 0:
      echo retClosure
    result = readFile(tmpDstFile)
    rmFileCT(tmpDstFile)
  else:
    echo "closure compiler: not found - skip"
    result = code
  removeTmpFilesCT(srcFileDir)
  rmFileCT(tmpExtFile)
  rmFileCT(tmpSrcFile)

template staticMinifyJsCode*(baseDir, code, extern: string): string =
  staticMinifyJsCode(baseDir, code, extern, randomStrCT())


when isMainModule:
  echo staticExecCode(echo "hello")

  echo staticExecCode(echo "hello!")

  echo staticCompileJsCode(binDir, """
echo "hello!"
""")

# Copyright (c) 2022 zenywallet

import std/os
import std/macros
import std/strformat
import std/strutils
import std/compilesettings
import std/random
import std/osproc

type
  ExecError* = object of CatchableError

const srcFile = currentSourcePath()
const (srcFileDir, srcFileName, srcFileExt) = splitFile(srcFile)
const binDir = srcFileDir / "bin"
const execHelperExe = binDir / "exec_helper"
const execHelperSrc = srcFileDir / "exec_helper" & srcFileExt

macro buildExecHelper() =
  echo staticExec("nim c -o:bin/ " & execHelperSrc)
buildExecHelper()

proc randomStrCT*(): string {.compileTime.} = staticExec(execHelperExe & " randomstr")

proc randomStr*(): string =
  const letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
  var r = initRand()
  result = newString(13)
  for i in 0..<result.len:
    result[i] = r.sample(letters)

proc rmFileCT*(filename: string) {.compileTime.} =
  echo staticExec(execHelperExe & " rmfile " & filename)

proc rmFile*(filename: string) =
  echo execCmdEx(execHelperExe & " rmfile " & filename).output.strip()

proc basicExternCT*(filename: string): string {.compileTime.} =
  staticExec(execHelperExe & " basicextern " & filename)

proc basicExtern*(filename: string): string  =
  execCmdEx(execHelperExe & " basicextern " & filename).output.strip()

proc removeTmpFilesCT(removeDir: string) {.compileTime.} =
  var tmpFiles = removeDir / srcFileName & "_tmp" & "[[:digit:]]*"
  var ret = staticExec("find " & tmpFiles & " -type f -mmin +60 -print0 2> /dev/null | xargs -r0 rm")
  if ret.len > 0:
    echo ret

proc removeTmpFiles(removeDir: string) =
  var tmpFiles = removeDir / srcFileName & "_tmp" & "[[:digit:]]*"
  var ret = execCmdEx("find " & tmpFiles & " -type f -mmin +60 -print0 2> /dev/null | xargs -r0 rm").output.strip()
  if ret.len > 0:
    echo ret

proc removeCacheDirsCT(removeDir: string) {.compileTime.} =
  var tmpFiles = removeDir / srcFileName & "_tmp" & "[[:digit:]]*"
  var ret = staticExec("find \"" & tmpFiles & "\" -type d -mmin +5 -print0 2> /dev/null | xargs -r0 rm -rf")
  if ret.len > 0:
    echo ret

var tmpFileIdCT {.compileTime.}: int = 0
var tmpFileId: int = 0

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

proc removeThreadVarPatch(code: string): string =
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

proc compileJsCode*(srcFileDir: string, code: string, rstr: string): string =
  inc(tmpFileId)
  let tmpNameFile = srcFileDir / srcFileName & "_tmp" & $tmpFileId & rstr
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
  echo execCmdEx("nim js -d:release --mm:orc" & verbosity & " -o:" & tmpJsFile & " " & tmpSrcFile).output.strip()
  if not fileExists(tmpJsFile):
    rmFile(tmpSrcFile)
    raise newException(ExecError, "nim js failed")
  result = readFile(tmpJsFile)
  result = removeThreadVarPatch(result)
  removeTmpFiles(srcFileDir)
  rmFile(tmpJsFile)
  rmFile(tmpSrcFile)

template compileJsCode*(baseDir, code: string): string =
  compileJsCode(baseDir, code, randomStr())

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

proc minifyJsCode*(srcFileDir: string, code: string, extern: string, rstr: string): string =
  inc(tmpFileId)
  let tmpNameFile = srcFileDir / srcFileName & "_tmp" & $tmpFileId & rstr
  let tmpSrcFile = tmpNameFile & ".js"
  let tmpExtFile = tmpNameFile & "_extern.js"
  let tmpDstFile = tmpNameFile & "_min.js"
  writeFile(tmpSrcFile, code)
  writeFile(tmpExtFile, extern & basicExtern(tmpSrcFile))
  let downloadClosureCompiler = execCmdEx("""
ZENYJS_CACHE_DIR=${XDG_CACHE_HOME:-"$HOME/.cache"}/zenyjs
if [ -x "$(command -v google-closure-compiler)" ]; then
  echo "download closure-compiler skip"
elif ls $ZENYJS_CACHE_DIR/closure-compiler-*.jar 1> /dev/null 2>&1; then
  echo "download closure-compiler skip"
else
  mkdir -p $ZENYJS_CACHE_DIR
  mvn dependency:get -e -Ddest=$ZENYJS_CACHE_DIR -Dartifact=com.google.javascript:closure-compiler:LATEST
fi
""").output.strip()
  echo downloadClosureCompiler
  let closureCompiler = execCmdEx("""
ZENYJS_CACHE_DIR=${XDG_CACHE_HOME:-"$HOME/.cache"}/zenyjs
if [ -x "$(command -v google-closure-compiler)" ]; then
  closure_compiler="google-closure-compiler"
elif ls $ZENYJS_CACHE_DIR/closure-compiler-*.jar 1> /dev/null 2>&1; then
  closure_compiler="java -jar $(ls $ZENYJS_CACHE_DIR/closure-compiler-*.jar | sort -r | head -n1)"
fi
echo $closure_compiler
""").output.strip()
  if closureCompiler.len > 0:
    echo "closure compiler: " & closureCompiler
    let retClosure = execCmdEx(fmt"""
  {closureCompiler} --compilation_level ADVANCED --jscomp_off=checkVars \
  --jscomp_off=checkTypes --jscomp_off=uselessCode --js_output_file="{tmpDstFile}" \
  --externs "{tmpExtFile}" "{tmpSrcFile}" 2>&1 | cut -c 1-240
  """).output.strip()
    if retClosure.len > 0:
      echo retClosure
    result = readFile(tmpDstFile)
    rmFile(tmpDstFile)
  else:
    echo "closure compiler: not found - skip"
    result = code
  removeTmpFiles(srcFileDir)
  rmFile(tmpExtFile)
  rmFile(tmpSrcFile)

template minifyJsCode*(baseDir, code, extern: string): string =
  minifyJsCode(baseDir, code, extern, randomStr())


when isMainModule:
  echo staticExecCode(echo "hello")

  echo staticExecCode(echo "hello!")

  echo staticCompileJsCode(srcFileDir, """echo "hello!"""")

  echo compileJsCode(srcFileDir, """echo "hello!"""")

  echo minifyJsCode(srcFileDir, """console.log("Hello," + " " + "world!");""", "")

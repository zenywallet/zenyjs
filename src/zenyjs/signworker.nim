# Copyright (c) 2026 zenywallet

when defined(js):
  import zenyjs
  import core

  type
    EventListenerCb = proc(evt: JsObject)
  var onMessage {.importc: "onmessage", nodecl.}: EventListenerCb
  var process {.importc, nodecl.}: JsObject

  var signWorker = JsObject{}
  var Module {.exportc.}: JsObject

  Module = JsObject{
    onRuntimeInitialized: proc() =
      Module.malloc = proc(size: int): JsObject =
        Module.modCall("_malloc".cstring, size.toJs)
      Module.free = proc(p: JsObject) =
        Module.modCall("_free".cstring, p)

      when declared(arraylib):
        arraylib.init(Module)

      signWorker.setTaskData = Module.cwrap("set_task_data", jsNull, [NumVar, NumVar, NumVar, NumVar, NumVar])
      signWorker.startTaskWorker = Module.cwrap("start_task_worker", jsNull, [].toJs)
      signWorker.stopTaskWorker = Module.cwrap("stop_task_worker", jsNull, [].toJs)

      if process.isDefined():
        let worker_threads = require("worker_threads")
        worker_threads.parentPort.onmessage = proc(evt: JsObject) =
          if evt.data.cmd.to(bool) and evt.data.cmd == "task".toJs and evt.data.data.to(bool):
            let data = evt.data.data
            for d in data:
              var signHash = newUint8Array(d.txSignHash[0])
              var prvKey = newUint8Array(d.prvKeys[0])
              var h = signHash.toBytes
              var prv = prvKey.toBytes
              signWorker.setTaskData(d.id, 0, h.handle, prv.handle, d.level)
              signWorker.startTaskWorker()
              break

        proc sendReady() =
          worker_threads.parentPort.postMessage(JsObject{cmd: "ready".cstring})
        sendReady()
      else:
        onMessage = proc(evt: JsObject) =
          postMessage(JsObject{cmd: "I am signworker!".cstring})

        proc sendReady() =
          postMessage(JsObject{cmd: "ready".cstring})
        sendReady(),
    preRun: [].toJs,
    postRun: [].toJs,
    print: proc() =
      console.log([].toJs.slice.call(arguments).join(' ')),
    printErr: proc() =
      console.error([].toJs.slice.call(arguments).join(' ')),
    setStatus: proc(text: JsObject) =
      console.log("status: " & text.to(cstring)),
    monitorRunDependencies: proc(left: JsObject) = discard
  }

elif defined(emscripten):
  import std/os
  import core
  import hash
  import eckey
  import seed

  const srcPath = currentSourcePath().parentDir()
  {.passL: "--extern-pre-js " & srcPath / "signworker_loader.js".}
  {.emit: "#include <emscripten.h>".}
  proc emscripten_sleep(ms: uint) {.importc.}

  type
    TaskData = object
      id: int
      idx: int
      hash: Hash
      prv: PrivateKey
      level: int
      lowDerSize: int

  var taskData: TaskData
  var abort: bool
  var skipCount: int
  var skipMod: int = 100

  proc setTaskData*(id: int, idx: int, hash: var Hash, prv: PrivateKey, level: int) {.exportc: "set_task_data".} =
    taskData.id = id
    taskData.idx = idx
    taskData.hash = hash
    taskData.prv = prv
    taskData.level = level
    taskData.lowDerSize = 71 - level

  proc startTaskWorker*() {.exportc: "start_task_worker".} =
    abort = false
    skipCount = 0
    var nonce = cryptSeed(32)

    template incNonce() =
      for i in 0..<32:
        inc(nonce[i])
        if nonce[i] != 0: break

    while not abort:
      var der = sign(taskData.prv, taskData.hash, nonce)
      if der.len <= taskData.lowDerSize and der.len != 0:
        var derCString = ($der.toBytes).cstring
        var taskId = taskData.id
        var taskIdx = taskData.idx
        {.emit: """
          EM_ASM({
            try {
              if(typeof process !== 'undefined') {
                const { parentPort } = require('node:worker_threads');
                parentPort.postMessage({cmd: "find", data: {id: $0, idx: $1, der: UTF8ToString($2)}});
              } else {
                postMessage({cmd: "find", data: {id: $0, idx: $1, der: UTF8ToString($2)}});
              }
            } catch(e) {
              console.error('except:', e);
            }
          }, `taskId`, `taskIdx`, `derCString`);
        """.}
        break
      inc(skipCount)
      if skipCount >= skipMod:
        emscripten_sleep(0)
        skipCount = 0
      incNonce()

  proc stopTaskWorker*() {.exportc: "stop_task_worker".} =
    abort = true

  const DEFAULT_EXPORTED_FUNCTIONS = ["_malloc", "_free", "_start_task_worker", "_stop_task_worker", "_set_task_data"]
  const DEFAULT_EXPORTED_RUNTIME_METHODS = ["ccall", "cwrap", "UTF8ToString",
    "stackSave", "stackAlloc", "stackRestore",
    "HEAPU8", "HEAP8", "HEAPU32", "HEAP32", "HEAPU64", "HEAP64"]

  import macros
  macro collectExportedFunctions*(): untyped =
    result = nnkStmtList.newTree()
    var bracket = nnkBracket.newTree()
    for functionName in DEFAULT_EXPORTED_FUNCTIONS:
      bracket.add(newLit(functionName))
    when declared(arraylib.EXPORTED_FUNCTIONS):
      for functionName in arraylib.EXPORTED_FUNCTIONS:
        bracket.add(newLit(functionName))
    result.add(
      nnkConstSection.newTree(
        nnkConstDef.newTree(
          newIdentNode("exportedFunctions"),
          newEmptyNode(),
          bracket
        )
      )
    )

  collectExportedFunctions()

  {.passL: "-s EXPORTED_FUNCTIONS='" & $exportedFunctions & "'".}
  {.passL: "-s EXPORTED_RUNTIME_METHODS='" & $DEFAULT_EXPORTED_RUNTIME_METHODS & "'".}


else:
  # signworker build

  import std/os
  import std/osproc
  import emsdkenv

  const srcDir = currentSourcePath().parentDir()

  proc errCheck(errCode: int) =
    if errCode != 0:
      raise

  proc exec(cmd: string) = errCheck execCmd(cmd)

  template withDir(dir: string; body: untyped): untyped =
    let curDir = getCurrentDir()
    try:
      setCurrentDir(dir)
      body
    finally:
      setCurrentDir(curDir)

  withDir srcDir:
    exec "nim js -d:release --mm:orc -o:signworker_loader.js signworker.nim"
    emsdkEnv("nim c -d:release -d:emscripten --noMain:on --mm:orc -o:signworker.js signworker.nim")

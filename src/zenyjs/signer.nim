# Copyright (c) 2026 zenywallet

import std/macros
import std/atomics
import std/cpuinfo
import std/os
import std/times
import std/selectors
import arraylib
import hash
import eckey
import seed

type
  SignerData* = object
    txSignHash: Array[Hash]
    signData: Array[tuple[prv: PrivateKey, der: Array[byte]]]
    level: int
    done: bool

var cpuCount*: int
var signerQueue: Array[SignerData]
var signerActive = false
var workerCounter: Atomic[uint]
var selector: Selector[int]
var event: SelectEvent

proc worker() {.thread.} =
  var nonce = cryptSeed(32)

  template incNonce() =
    for i in 0..<32:
      inc(nonce[i])
      if nonce[i] != 0: break

  for i in 0..<signerQueue.len:
    var signerData = addr signerQueue[i]
    if not signerData.done:
      var signDataLen = signerData.signData.len
      var lowDerSize = 71 - signerData.level
      var target = lowDerSize * signerData.signData.len

      block WorkerLoop:
        while signerActive:
          var j = workerCounter.fetchAdd(1) mod signDataLen.uint
          var curDerLen = signerData.signData[j].der.len
          if curDerLen == 0 or curDerLen > lowDerSize:
            var der = sign(signerData.signData[j].prv, signerData.txSignHash[j], nonce)
            curDerLen = signerData.signData[j].der.len
            if curDerLen == 0 or der.len < curDerLen:
              signerData.signData[j].der = der
          else:
            block CheckTarget:
              var derTotal = 0
              for k in 0..<signDataLen:
                var derLen = signerData.signData[k].der.len
                if derLen == 0:
                  break CheckTarget
                derTotal = derTotal + derLen
              if derTotal <= target:
                signerData.done = true
                event.trigger()
                break WorkerLoop
          incNonce()
  event.trigger()

cpuCount = countProcessors()
var workerThreads = newSeq[Thread[void]](cpuCount)


proc signerStart*(onStatus: proc(progress, total, elapse: int, progressUpdate: bool), onDone: proc()) =
  var progress = 0
  var start = epochTime()
  onStatus(progress, signerQueue.len, 0, true)
  signerActive = true
  selector = newSelector[int]()
  event = newSelectEvent()
  selector.registerEvent(event, 114)
  for i in 0..<cpuCount:
    createThread(workerThreads[i], worker)

  block WaitSelector:
    while true:
      let readyKeys = selector.select(1000)
      if not signerActive: break
      if readyKeys.len == 0:
        onStatus(progress, signerQueue.len, int(epochTime() - start), false)
      else:
        block CheckStatus:
          for i in progress..<signerQueue.len:
            var signerData = addr signerQueue[i]
            if not signerData.done:
              if progress != i:
                inc(progress)
                onStatus(progress, signerQueue.len, int(epochTime() - start), true)
              break CheckStatus
          signerActive = false
          inc(progress)
          onStatus(progress, signerQueue.len, int(epochTime() - start), true)
          break WaitSelector

  workerThreads.joinThreads()
  event.close()
  selector.close()
  onDone()

proc signerStop*() =
  signerActive = false
  workerThreads.joinThreads()

proc clearSignerTask*() =
  signerStop()
  signerQueue.clear()

proc addSignerTask*(txSignHash: Array[Hash], prvKeys: Array[PrivateKey], level: int): int {.discardable.} =
  var taskId = signerQueue.len
  var signData: Array[tuple[prv: PrivateKey, der: Array[byte]]]
  for prv in prvKeys:
    signData.add((prv, newArray[byte](0)))
  signerQueue.add(SignerData(txSignHash: txSignHash, signData: signData, level: level, done: false))
  taskId

proc getSignerTaskDers*(taskId: int): Array[Array[byte]] =
  if signerQueue[taskId].done:
    for i in 0..<signerQueue[taskId].signData.len:
      result.add(signerQueue[taskId].signData[i].der)

macro signerStart*(body: untyped): untyped =
  quote do:
    `body`
    when not declared(onStatus):
      proc onStatus(progress, total, elapse: int, progressUpdate: bool) = discard
    when not declared(onDone):
      proc onDone() = discard
    signerStart(onStatus, onDone)

macro signerStart*(): untyped =
  quote do:
    proc onStatus(progress, total, elapse: int, progressUpdate: bool) = discard
    proc onDone() = discard
    signerStart(onStatus, onDone)


when isMainModule:
  import zenyjs
  import core
  import tx as txlib
  import address
  import utils
  import eckey
  import hex
  import bytes
  import std/json

  networksDefault()

  zenyjs.ready:
    var txid0 = Hash(Hex("f347f3898ac1368463767cce59f359c83eaa1c32c0321e1f1aeaeaf52a4edaeb"))
    var n0 = 0'u32
    var txid1 = Hash(Hex("35645a2cb6b7270efda4cd69f6d69ec33b6eed6db5320fe7411c020dff6d7534"))
    var n1 = 0'u32
    var inputScript0 = BitZeny_mainnet.getScript("ZqWp638LJVdiFkHGGLD5jh8sQnPQbWcMco")
    var inputScript1 = BitZeny_mainnet.getScript("ZherrACZpqr6wtVq6u52DjgWw3nc8roVLR")
    var outputScript0 = BitZeny_mainnet.getScript("ZqBb6zr8P7ijKZsGfv4MihGbuLYNsFgHCF")
    var outputScript1 = BitZeny_mainnet.getScript("ZqDF1JhpkoK8zjNxYozYHCuy7rafhiFFga")
    var prv0 = PrivateKey(Hex("7008e08494e78a4576595c08372ef08ff3c5a5fb669d04ab688af5ec05d4e419"))
    var prv1 = PrivateKey(Hex("b416f75b5dc0679154c6d1d8fd0932816eaee59782d8f67fb3465ca0662f267b"))
    var emptySig: Sig

    var tx = newTx()
    tx.ver = 2'i32
    tx.ins.add (tx: txid0, n: n0, sig: emptySig, sequence: 0xffffffff'u32)
    tx.ins.add (tx: txid1, n: n1, sig: emptySig, sequence: 0xffffffff'u32)
    tx.outs.add (value: 39390000'u64, script: outputScript0)
    tx.outs.add (value: 610000'u64 - 372'u64, script: outputScript1)

    var tx_fee372 = tx
    var tx_fee370 = tx
    tx_fee370.outs[1] = (value: 610000'u64 - 370'u64, script: outputScript1)
    var tx_fee368 = tx
    tx_fee368.outs[1] = (value: 610000'u64 - 368'u64, script: outputScript1)

    var txs: Array[Tx]
    txs.add(tx_fee372)
    txs.add(tx_fee370)
    txs.add(tx_fee368)

    var txSignHash1: Array[Hash]
    var txSignHash2: Array[Hash]
    var txSignHash3: Array[Hash]

    tx_fee372.ins[0].sig = inputScript0.Sig
    txSignHash1.add(sha256d((tx_fee372, SIGHASH_ALL.uint32).toBytes))
    tx_fee372.ins[0].sig = emptySig
    tx_fee372.ins[1].sig = inputScript1.Sig
    txSignHash1.add(sha256d((tx_fee372, SIGHASH_ALL.uint32).toBytes))

    tx_fee370.ins[0].sig = inputScript0.Sig
    txSignHash2.add(sha256d((tx_fee370, SIGHASH_ALL.uint32).toBytes))
    tx_fee370.ins[0].sig = emptySig
    tx_fee370.ins[1].sig = inputScript1.Sig
    txSignHash2.add(sha256d((tx_fee370, SIGHASH_ALL.uint32).toBytes))

    tx_fee368.ins[0].sig = inputScript0.Sig
    txSignHash3.add(sha256d((tx_fee368, SIGHASH_ALL.uint32).toBytes))
    tx_fee368.ins[0].sig = emptySig
    tx_fee368.ins[1].sig = inputScript1.Sig
    txSignHash3.add(sha256d((tx_fee368, SIGHASH_ALL.uint32).toBytes))

    var prvKeys: Array[PrivateKey] = @^[prv0, prv1]
    clearSignerTask()
    var taskId1 = addSignerTask(txSignHash1, prvKeys, level = 1) # 70
    var taskId2 = addSignerTask(txSignHash2, prvKeys, level = 2) # 69
    var taskId3 = addSignerTask(txSignHash3, prvKeys, level = 3) # 68

    signerStart:
      proc onStatus(progress, total, elapse: int, progressUpdate: bool) =
        if progressUpdate:
          echo "onStatus progress=", progress, "/", total, " elapse=", elapse
        else:
          echo "onStatus elapse=", elapse
          if elapse >= 60 and progress > 0:
            signerStop()

      proc onDone() =
        for (taskId, tx) in [(taskId3, tx_fee368), (taskId2, tx_fee370), (taskId1, tx_fee372)]:
          var ders = getSignerTaskDers(taskId)
          if ders.len == prvKeys.len:
            for i in 0..<ders.len:
              tx.ins[i].sig = Sig(PushData(ders[i], SIGHASH_ALL.uint8), PushData(prvKeys[i].pub))
            echo (%tx).pretty
            echo tx.toBytes, " ", tx.toBytes.len
            break

# Copyright (c) 2022 zenywallet

const ZenyJsExterns* = """
var zenyjsexterns = {
  ZenyJS: {},
  zenyjsMod: {
    onRuntimeInitialized: function() {},
    preRun: [],
    postRun: [],
    print: function() {},
    printErr: function() {},
    setStatus: function() {},
    monitorRunDependencies: function() {}
  },
  cwrap: function() {},
  ccall: function() {},
  _malloc: function() {},
  _free: function() {},
  stackSave: function() {},
  stackAlloc: function() {},
  stackRestore: function() {},
  UTF8ToString: function() {},
  HEAPU8: {},
  HEAPU32: {},
  buffer: 0,
  sig: {},
  isAsync: function() {}
};

var fomantic = {
  tab: 0,
  checkbox: 0,
  rating: {
    icon: 0,
    initialRating: 0,
    maxRating: 0,
    fireOnInit: 0,
    clearable: 0,
    interactive: 0,
    onRate: function() {},
    onChange: function() {}
  },
  toast: {
    title: 0,
    message: 0,
    class: 0,
    className: {
      toast: 0
    },
    displayTime: 0
  },
  modal: {
    onShow: function() {},
    onVisible: function() {},
    onHide: function() {},
    onHidden: function() {},
    onApprove: function() {},
    onDeny: function() {}
  }
};

var nodejs = {
  global: 0,
  Module: function() {},
  fs: {
    readFileSync: function() {},
    readFile: function() {}
  },
  FS: {
    createDataFile: 0,
    createPreloadedFile: 0
  },
  nodePath: 0,
  process: {
    versions: {
      node: 0
    },
    on: function() {},
    argv: [],
    exitCode: 0
  },
  randomBytes: function() {}
};

var jq = {
  val: function() {}
};
"""

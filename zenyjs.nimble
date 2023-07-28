# Package

version       = "0.1.0"
author        = "zenywallet"
description   = "A web wallet library for BitZeny"
license       = "MIT"
srcDir        = "src"


# Dependencies

requires "nim >= 1.6.4"


task emsdk, "Emscripten SDK install":
  withDir "deps/emsdk":
    exec "git pull"
    exec "./emsdk install latest"
    exec "./emsdk activate latest"
    exec ". ./emsdk_env.sh"

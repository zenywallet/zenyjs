# Copyright (c) 2020 zenywallet

import arraylib

type
  PushData* {.borrow: `.`.} = distinct Array[byte]

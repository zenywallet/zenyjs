##  Copyright (c) 2017, 2021 Pieter Wuille
##
##  Permission is hereby granted, free of charge, to any person obtaining a copy
##  of this software and associated documentation files (the "Software"), to deal
##  in the Software without restriction, including without limitation the rights
##  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
##  copies of the Software, and to permit persons to whom the Software is
##  furnished to do so, subject to the following conditions:
##
##  The above copyright notice and this permission notice shall be included in
##  all copies or substantial portions of the Software.
##
##  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
##  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
##  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
##  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
##  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
##  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
##  THE SOFTWARE.
##

type
  uint8_t = uint8

## * Encode a SegWit address
##
##   Out: output:   Pointer to a buffer of size 73 + strlen(hrp) that will be
##                  updated to contain the null-terminated address.
##   In:  hrp:      Pointer to the null-terminated human readable part to use
##                  (chain/network specific).
##        ver:      Version of the witness program (between 0 and 16 inclusive).
##        prog:     Data bytes for the witness program (between 2 and 40 bytes).
##        prog_len: Number of data bytes in prog.
##   Returns 1 if successful.
##
proc segwit_addr_encode*(output: cstring; hrp: cstring; ver: cint; prog: ptr uint8_t;
                        prog_len: csize_t): cint {.importc.}
## * Decode a SegWit address
##
##   Out: ver:      Pointer to an int that will be updated to contain the witness
##                  program version (between 0 and 16 inclusive).
##        prog:     Pointer to a buffer of size 40 that will be updated to
##                  contain the witness program bytes.
##        prog_len: Pointer to a size_t that will be updated to contain the length
##                  of bytes in prog.
##        hrp:      Pointer to the null-terminated human readable part that is
##                  expected (chain/network specific).
##        addr:     Pointer to the null-terminated address.
##   Returns 1 if successful.
##
proc segwit_addr_decode*(ver: ptr cint; prog: ptr uint8_t; prog_len: ptr csize_t;
                        hrp: cstring; `addr`: cstring): cint {.importc.}
## * Supported encodings.
type
  bech32_encoding* = enum
    BECH32_ENCODING_NONE, BECH32_ENCODING_BECH32, BECH32_ENCODING_BECH32M
## * Encode a Bech32 or Bech32m string
##
##   Out: output:  Pointer to a buffer of size strlen(hrp) + data_len + 8 that
##                 will be updated to contain the null-terminated Bech32 string.
##   In: hrp :     Pointer to the null-terminated human readable part.
##       data :    Pointer to an array of 5-bit values.
##       data_len: Length of the data array.
##       enc:      Which encoding to use (BECH32_ENCODING_BECH32{,M}).
##   Returns 1 if successful.
##
proc bech32_encode*(output: cstring; hrp: cstring; data: ptr uint8_t;
                   data_len: csize_t; enc: bech32_encoding): cint {.importc.}
## * Decode a Bech32 or Bech32m string
##
##   Out: hrp:      Pointer to a buffer of size strlen(input) - 6. Will be
##                  updated to contain the null-terminated human readable part.
##        data:     Pointer to a buffer of size strlen(input) - 8 that will
##                  hold the encoded 5-bit data values.
##        data_len: Pointer to a size_t that will be updated to be the number
##                  of entries in data.
##   In: input:     Pointer to a null-terminated Bech32 string.
##   Returns BECH32_ENCODING_BECH32{,M} to indicate decoding was successful
##   with the specified encoding standard. BECH32_ENCODING_NONE is returned if
##   decoding failed.
##
proc bech32_decode*(hrp: cstring; data: ptr uint8_t; data_len: ptr csize_t;
                   input: cstring): bech32_encoding {.importc.}


import os
const bech32Path = splitPath(currentSourcePath()).head / "deps/bech32/ref/c"
{.compile: bech32Path / "segwit_addr.c".}

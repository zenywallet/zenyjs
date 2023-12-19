# Copyright (c) 2021 zenywallet

when (compiles do: import zenyjs):
  import zenyjs
  import zenyjs/core
  import zenyjs/otp
  import zenyjs/base32
else:
  import ../src/zenyjs
  import ../src/zenyjs/core
  import ../src/zenyjs/otp
  import ../src/zenyjs/base32

import std/times

zenyjs.ready:
  # https://tools.ietf.org/html/rfc6238
  var totp_sha1 = newTotp("12345678901234567890", 8, 30, SHA1)
  var totp_sha256 = newTotp("12345678901234567890123456789012", 8, 30, SHA256)
  var totp_sha512 = newTotp("1234567890123456789012345678901234567890123456789012345678901234", 8, 30, SHA512)
  echo totp_sha1.generate(59)
  echo totp_sha256.generate(59)
  echo totp_sha512.generate(59)
  echo totp_sha1.generate(1111111109)
  echo totp_sha256.generate(1111111109)
  echo totp_sha512.generate(1111111109)
  echo totp_sha1.generate(1111111111)
  echo totp_sha256.generate(1111111111)
  echo totp_sha512.generate(1111111111)
  echo totp_sha1.generate(1234567890)
  echo totp_sha256.generate(1234567890)
  echo totp_sha512.generate(1234567890)
  echo totp_sha1.generate(2000000000)
  echo totp_sha256.generate(2000000000)
  echo totp_sha512.generate(2000000000)
  echo totp_sha1.generate(20000000000'u64)
  echo totp_sha256.generate(20000000000'u64)
  echo totp_sha512.generate(20000000000'u64)
  echo "-----"

  # google authenticator test
  var t = newTotp(base32.dec("testtesttesttest")) # 6, 30, SHA1
  echo t.generate(epochTime().uint64)

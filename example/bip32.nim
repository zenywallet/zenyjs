# Copyright (c) 2021 zenywallet

when (compiles do: import zenyjs):
  import zenyjs
  import zenyjs/core
  import zenyjs/bip32
else:
  import ../src/zenyjs
  import ../src/zenyjs/core
  import ../src/zenyjs/bip32

zenyjs.ready:
  block test1:
    echo "--- Test vector 1"
    var seed = Hex("000102030405060708090a0b0c0d0e0f").toBytes
    echo "Seed: ", seed
    echo "Chain m"
    var m = bip32.master(seed)
    echo "ext pub: ", m.xpub()
    echo "ext prv: ", m.xprv()

    echo "Chain m/0'"
    var m_0h = m.hardened(0)
    echo "ext pub: ", m_0h.xpub()
    echo "ext prv: ", m_0h.xprv()

    echo "Chain m/0'/1"
    var m_0h_1 = m_0h.derive(1)
    echo "ext pub: ", m_0h_1.xpub()
    echo "ext prv: ", m_0h_1.xprv()

    echo "Chain m/0'/1/2'"
    var mm_0h_1_2h = m_0h_1.hardened(2)
    echo "ext pub: ", mm_0h_1_2h.xpub()
    echo "ext prv: ", mm_0h_1_2h.xprv()

    echo "Chain m/0'/1/2'/2"
    var mm_0h_1_2h_2 = mm_0h_1_2h.derive(2)
    echo "ext pub: ", mm_0h_1_2h_2.xpub()
    echo "ext prv: ", mm_0h_1_2h_2.xprv()

    echo "Chain m/0'/1/2'/2/1000000000"
    var mm_0h_1_2h_2_1000000000 = mm_0h_1_2h_2.derive(1000000000)
    echo "ext pub: ", mm_0h_1_2h_2_1000000000.xpub()
    echo "ext prv: ", mm_0h_1_2h_2_1000000000.xprv()

  block test2:
    echo "--- Test vector 2"
    var seed = Hex("fffcf9f6f3f0edeae7e4e1dedbd8d5d2cfccc9c6c3c0bdbab7b4b1aeaba8a5a29f9c999693908d8a8784817e7b7875726f6c696663605d5a5754514e4b484542").toBytes
    echo "Seed: ", seed
    echo "Chain m"
    var m = bip32.master(seed)
    echo "ext pub: ", m.xpub()
    echo "ext prv: ", m.xprv()

    echo "Chain m/0"
    var m_0 = m.derive(0)
    echo "ext pub: ", m_0.xpub()
    echo "ext prv: ", m_0.xprv()

    echo "Chain m/0/2147483647'"
    var m_0_2147483647h = m_0.hardened(2147483647)
    echo "ext pub: ", m_0_2147483647h.xpub()
    echo "ext prv: ", m_0_2147483647h.xprv()

    echo "Chain m/0/2147483647'/1"
    var m_0_2147483647h_1 = m_0_2147483647h.derive(1)
    echo "ext pub: ", m_0_2147483647h_1.xpub()
    echo "ext prv: ", m_0_2147483647h_1.xprv()

    echo "Chain m/0/2147483647'/1/2147483646'"
    var m_0_2147483647h_1_2147483646h = m_0_2147483647h_1.hardened(2147483646)
    echo "ext pub: ", m_0_2147483647h_1_2147483646h.xpub()
    echo "ext prv: ", m_0_2147483647h_1_2147483646h.xprv()

    echo "Chain m/0/2147483647'/1/2147483646'/2"
    var m_0_2147483647h_1_2147483646h_2 = m_0_2147483647h_1_2147483646h.derive(2)
    echo "ext pub: ", m_0_2147483647h_1_2147483646h_2.xpub()
    echo "ext prv: ", m_0_2147483647h_1_2147483646h_2.xprv()

  block test3:
    echo "--- Test vector 3"
    var seed = Hex("4b381541583be4423346c643850da4b320e46a87ae3d2a4e6da11eba819cd4acba45d239319ac14f863b8d5ab5a0d0c64d2e8a1e7d1457df2e5a3c51c73235be").toBytes
    echo "Seed: ", seed
    echo "Chain m"
    var m = bip32.master(seed)
    echo "ext pub: ", m.xpub()
    echo "ext prv: ", m.xprv()

    echo "Chain m/0'"
    var m_0h = m.hardened(0)
    echo "ext pub: ", m_0h.xpub()
    echo "ext prv: ", m_0h.xprv()

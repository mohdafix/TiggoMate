import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

/// CarLinko remote-control payload encryption (v1.14.10+ / T-Box >= 2.3.1).
///
/// Newer T-Box firmwares (e.g. 2.3.1_050F01R / 2.3.1_051A01R) reject plain
/// `74xxyy` control commands with `__7404` (tbox_auth_fail) and require:
///   frame      = bytes.fromhex(opcode) + VIN.ascii + userId.ascii
///                (zero-padded to a 16-byte multiple)
///   randomHex  = 8 random bytes as 16 lowercase hex chars
///   key        = bytes.fromhex("A0F47CB6677BE6A3" + randomHex)
///   data field = "66" + randomHex + hex(AES-128-ECB(key, frame))
///
/// Init commands (`2301`, `24`, `77`, `7801`) remain plain.
class CarLinkoCrypto {
  CarLinkoCrypto._();

  static const String _fixedKeyHex = 'A0F47CB6677BE6A3';

  static const List<int> _sbox = <int>[
    0x63, 0x7C, 0x77, 0x7B, 0xF2, 0x6B, 0x6F, 0xC5, 0x30, 0x01, 0x67, 0x2B, 0xFE, 0xD7, 0xAB, 0x76,
    0xCA, 0x82, 0xC9, 0x7D, 0xFA, 0x59, 0x47, 0xF0, 0xAD, 0xD4, 0xA2, 0xAF, 0x9C, 0xA4, 0x72, 0xC0,
    0xB7, 0xFD, 0x93, 0x26, 0x36, 0x3F, 0xF7, 0xCC, 0x34, 0xA5, 0xE5, 0xF1, 0x71, 0xD8, 0x31, 0x15,
    0x04, 0xC7, 0x23, 0xC3, 0x18, 0x96, 0x05, 0x9A, 0x07, 0x12, 0x80, 0xE2, 0xEB, 0x27, 0xB2, 0x75,
    0x09, 0x83, 0x2C, 0x1A, 0x1B, 0x6E, 0x5A, 0xA0, 0x52, 0x3B, 0xD6, 0xB3, 0x29, 0xE3, 0x2F, 0x84,
    0x53, 0xD1, 0x00, 0xED, 0x20, 0xFC, 0xB1, 0x5B, 0x6A, 0xCB, 0xBE, 0x39, 0x4A, 0x4C, 0x58, 0xCF,
    0xD0, 0xEF, 0xAA, 0xFB, 0x43, 0x4D, 0x33, 0x85, 0x45, 0xF9, 0x02, 0x7F, 0x50, 0x3C, 0x9F, 0xA8,
    0x51, 0xA3, 0x40, 0x8F, 0x92, 0x9D, 0x38, 0xF5, 0xBC, 0xB6, 0xDA, 0x21, 0x10, 0xFF, 0xF3, 0xD2,
    0xCD, 0x0C, 0x13, 0xEC, 0x5F, 0x97, 0x44, 0x17, 0xC4, 0xA7, 0x7E, 0x3D, 0x64, 0x5D, 0x19, 0x73,
    0x60, 0x81, 0x4F, 0xDC, 0x22, 0x2A, 0x90, 0x88, 0x46, 0xEE, 0xB8, 0x14, 0xDE, 0x5E, 0x0B, 0xDB,
    0xE0, 0x32, 0x3A, 0x0A, 0x49, 0x06, 0x24, 0x5C, 0xC2, 0xD3, 0xAC, 0x62, 0x91, 0x95, 0xE4, 0x79,
    0xE7, 0xC8, 0x37, 0x6D, 0x8D, 0xD5, 0x4E, 0xA9, 0x6C, 0x56, 0xF4, 0xEA, 0x65, 0x7A, 0xAE, 0x08,
    0xBA, 0x78, 0x25, 0x2E, 0x1C, 0xA6, 0xB4, 0xC6, 0xE8, 0xDD, 0x74, 0x1F, 0x4B, 0xBD, 0x8B, 0x8A,
    0x70, 0x3E, 0xB5, 0x66, 0x48, 0x03, 0xF6, 0x0E, 0x61, 0x35, 0x57, 0xB9, 0x86, 0xC1, 0x1D, 0x9E,
    0xE1, 0xF8, 0x98, 0x11, 0x69, 0xD9, 0x8E, 0x94, 0x9B, 0x1E, 0x87, 0xE9, 0xCE, 0x55, 0x28, 0xDF,
    0x8C, 0xA1, 0x89, 0x0D, 0xBF, 0xE6, 0x42, 0x68, 0x41, 0x99, 0x2D, 0x0F, 0xB0, 0x54, 0xBB, 0x16,
  ];

  static const List<int> _rcon = <int>[
    0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1B, 0x36,
  ];

  static int _mul(int a, int b) {
    var r = 0;
    var aa = a & 0xFF;
    var bb = b & 0xFF;
    for (var i = 0; i < 8; i++) {
      if ((bb & 1) != 0) r ^= aa;
      final hi = (aa & 0x80) != 0;
      aa = (aa << 1) & 0xFF;
      if (hi) aa ^= 0x1B;
      bb >>= 1;
    }
    return r & 0xFF;
  }

  static List<Uint8List> _keyExpansion(Uint8List key) {
    if (key.length != 16) {
      throw ArgumentError.value(key.length, 'key.length', 'AES-128 requires 16-byte key');
    }
    final w = List<List<int>>.generate(44, (_) => List<int>.filled(4, 0));
    for (var i = 0; i < 4; i++) {
      for (var j = 0; j < 4; j++) {
        w[i][j] = key[i * 4 + j];
      }
    }
    for (var i = 4; i < 44; i++) {
      final temp = List<int>.from(w[i - 1]);
      if (i % 4 == 0) {
        final rot = <int>[temp[1], temp[2], temp[3], temp[0]];
        for (var j = 0; j < 4; j++) {
          temp[j] = _sbox[rot[j]];
        }
        temp[0] ^= _rcon[(i ~/ 4) - 1];
      }
      for (var j = 0; j < 4; j++) {
        w[i][j] = w[i - 4][j] ^ temp[j];
      }
    }
    return List<Uint8List>.generate(11, (r) {
      final rk = Uint8List(16);
      for (var c = 0; c < 4; c++) {
        for (var j = 0; j < 4; j++) {
          rk[c * 4 + j] = w[r * 4 + c][j];
        }
      }
      return rk;
    });
  }

  static Uint8List _encryptBlock(Uint8List block16, List<Uint8List> roundKeys) {
    final s = List<int>.from(block16);

    void addRoundKey(Uint8List rk) {
      for (var i = 0; i < 16; i++) {
        s[i] ^= rk[i];
      }
    }

    void subBytes() {
      for (var i = 0; i < 16; i++) {
        s[i] = _sbox[s[i]];
      }
    }

    void shiftRows() {
      final o = List<int>.filled(16, 0);
      for (var r = 0; r < 4; r++) {
        for (var c = 0; c < 4; c++) {
          o[r + 4 * c] = s[r + 4 * ((c + r) % 4)];
        }
      }
      for (var i = 0; i < 16; i++) {
        s[i] = o[i];
      }
    }

    void mixColumns() {
      for (var c = 0; c < 4; c++) {
        final i0 = 4 * c;
        final a0 = s[i0];
        final a1 = s[i0 + 1];
        final a2 = s[i0 + 2];
        final a3 = s[i0 + 3];
        s[i0] = _mul(a0, 2) ^ _mul(a1, 3) ^ a2 ^ a3;
        s[i0 + 1] = a0 ^ _mul(a1, 2) ^ _mul(a2, 3) ^ a3;
        s[i0 + 2] = a0 ^ a1 ^ _mul(a2, 2) ^ _mul(a3, 3);
        s[i0 + 3] = _mul(a0, 3) ^ a1 ^ a2 ^ _mul(a3, 2);
      }
    }

    addRoundKey(roundKeys[0]);
    for (var rnd = 1; rnd < 10; rnd++) {
      subBytes();
      shiftRows();
      mixColumns();
      addRoundKey(roundKeys[rnd]);
    }
    subBytes();
    shiftRows();
    addRoundKey(roundKeys[10]);
    return Uint8List.fromList(s);
  }

  /// AES-128-ECB encrypt [data] (must already be a multiple of 16 bytes).
  static Uint8List encryptEcb(Uint8List key, Uint8List data) {
    if (data.length % 16 != 0) {
      throw ArgumentError.value(data.length, 'data.length', 'Data must be 16-byte aligned');
    }
    final rk = _keyExpansion(key);
    final out = Uint8List(data.length);
    for (var i = 0; i < data.length; i += 16) {
      final block = _encryptBlock(Uint8List.sublistView(data, i, i + 16), rk);
      out.setRange(i, i + 16, block);
    }
    return out;
  }

  static Uint8List hexToBytes(String hex) {
    final clean = hex.replaceAll(RegExp(r'\s+'), '');
    if (clean.length % 2 != 0) {
      throw FormatException('Odd hex length: ${clean.length}');
    }
    final out = Uint8List(clean.length ~/ 2);
    for (var i = 0; i < clean.length; i += 2) {
      out[i ~/ 2] = int.parse(clean.substring(i, i + 2), radix: 16);
    }
    return out;
  }

  static String bytesToHex(Uint8List bytes) {
    final sb = StringBuffer();
    for (final b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }

  /// Build the `"66" + randomHex + ciphertextHex` payload for `74xx` commands.
  static String buildControlPayload(
    String opcode,
    String vin,
    String userId, {
    Uint8List? randomBytes,
  }) {
    final opBytes = hexToBytes(opcode);
    final vinBytes = utf8.encode(vin);
    final uidBytes = utf8.encode(userId);
    final rawLen = opBytes.length + vinBytes.length + uidBytes.length;
    final pad = (-rawLen) % 16;
    final paddedLen = rawLen + (pad < 0 ? pad + 16 : pad);
    final frame = Uint8List(paddedLen);
    frame.setRange(0, opBytes.length, opBytes);
    frame.setRange(opBytes.length, opBytes.length + vinBytes.length, vinBytes);
    frame.setRange(opBytes.length + vinBytes.length, rawLen, uidBytes);

    final rb = randomBytes ??
        (() {
          final rng = Random.secure();
          return Uint8List.fromList(List<int>.generate(8, (_) => rng.nextInt(256)));
        })();
    if (rb.length != 8) {
      throw ArgumentError.value(rb.length, 'randomBytes.length', 'Expected 8 random bytes');
    }
    final rh = bytesToHex(rb);
    final key = hexToBytes(_fixedKeyHex + rh);
    final ct = encryptEcb(key, frame);
    return '66$rh${bytesToHex(ct)}';
  }
}

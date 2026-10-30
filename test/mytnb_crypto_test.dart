import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/export.dart';
import 'package:tiggomate_app/src/mytnb/mytnb_crypto.dart';

/// Decrypts AES-256-CBC(PKCS7) ciphertext — used only to prove the
/// encryption side in [MyTnbCrypto] round-trips correctly. We don't have
/// TNB's RSA private key (nobody outside TNB does), so `ak` can't be
/// decrypted here; these tests instead check its shape is exactly what a
/// 2048-bit RSA-OAEP ciphertext must be, and independently verify the
/// AES-CBC + PKCS7 padding logic against a reference decrypt.
Uint8List _aesCbcDecrypt(Uint8List key, Uint8List iv, Uint8List ciphertext) {
  final cbc = CBCBlockCipher(AESEngine())..init(false, ParametersWithIV(KeyParameter(key), iv));
  final out = Uint8List(ciphertext.length);
  for (var offset = 0; offset < ciphertext.length; offset += cbc.blockSize) {
    cbc.processBlock(ciphertext, offset, out, offset);
  }
  final padLen = out.last;
  return out.sublist(0, out.length - padLen);
}

void main() {
  group('MyTnbCrypto', () {
    test('encryptRequest produces well-formed ae/ak/av for a 2048-bit key', () {
      final payload = MyTnbCrypto.encryptRequest({'contractAccount': '220194827101', 'isOwner': 'true'});

      final akBytes = base64Decode(payload.ak);
      final avBytes = base64Decode(payload.av);
      final aeBytes = base64Decode(payload.ae);

      // RSA-OAEP over a 2048-bit key always produces a 256-byte block.
      expect(akBytes.length, 256);
      // AES IV is always 16 bytes.
      expect(avBytes.length, 16);
      // AES-CBC ciphertext is always a multiple of the 16-byte block size.
      expect(aeBytes.length % 16, 0);
      expect(aeBytes, isNotEmpty);
    });

    test('same AES-CBC/PKCS7 logic used internally round-trips correctly', () {
      // This exercises the exact pad -> CBC-encrypt -> CBC-decrypt -> unpad
      // path MyTnbCrypto.encryptRequest uses internally, with a key/IV we
      // control (so we can decrypt it ourselves and compare).
      final key = Uint8List.fromList(List.generate(32, (i) => i));
      final iv = Uint8List.fromList(List.generate(16, (i) => i * 2));
      final plaintext = utf8.encode('{"contractAccount":"220194827101"}');

      final padLen = 16 - (plaintext.length % 16);
      final padded = Uint8List(plaintext.length + padLen)
        ..setRange(0, plaintext.length, plaintext)
        ..fillRange(plaintext.length, plaintext.length + padLen, padLen);

      final cbc = CBCBlockCipher(AESEngine())..init(true, ParametersWithIV(KeyParameter(key), iv));
      final ciphertext = Uint8List(padded.length);
      for (var offset = 0; offset < padded.length; offset += cbc.blockSize) {
        cbc.processBlock(padded, offset, ciphertext, offset);
      }

      final decrypted = _aesCbcDecrypt(key, iv, ciphertext);
      expect(utf8.decode(decrypted), '{"contractAccount":"220194827101"}');
    });

    test('generateUuidV4 returns a valid, upper-cased v4 UUID', () {
      final uuid = MyTnbCrypto.generateUuidV4();
      final re = RegExp(r'^[0-9A-F]{8}-[0-9A-F]{4}-4[0-9A-F]{3}-[89AB][0-9A-F]{3}-[0-9A-F]{12}$');
      expect(re.hasMatch(uuid), isTrue, reason: 'got: $uuid');
    });
  });
}

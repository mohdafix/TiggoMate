import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// The `dt` request envelope the myTNB mobile app's "APISecurityManager"
/// wraps every AWS-gateway / legacy ASMX request body in.
class MyTnbEncryptedPayload {
  /// Base64(AES-256-CBC(JSON request body)).
  final String ae;

  /// Base64(RSA-OAEP(AES key)).
  final String ak;

  /// Base64(AES IV).
  final String av;

  const MyTnbEncryptedPayload({required this.ae, required this.ak, required this.av});

  Map<String, String> toJson() => {'ae': ae, 'ak': ak, 'av': av};
}

/// Ports the AES-256-CBC + RSA-OAEP(SHA-1) hybrid encryption myTNB's mobile
/// app uses to protect its AWS-gateway and legacy ASMX request bodies.
///
/// The RSA public key below is TNB's own production key, embedded in the
/// myTNB mobile app's resources (`PKey.txt`) and published verbatim by the
/// open-source `python-mytnb` client (github.com/danieyal/python-mytnb) that
/// this was ported from. Encrypting with it is exactly what the real app
/// does; there is nothing secret being reproduced here.
class MyTnbCrypto {
  MyTnbCrypto._();

  static const String _prodModulusB64 =
      '2PUbfII3l4qZYNfvoIavtqL5PoXbnX093tJFHjre6Bspsy8gPMBoerv/GsjOpWVl'
      'f44y9ey9XUBuIzFYLYmtfAG0CQX90pJ4aDgnUpCiw02D/NShwVRwmujyFjhB3T'
      'beBbHofue/4KHZrbz2UQD0AgnC/HZiHRp2rFoWRGcud+xrUH6NJiF5YPYRgGKRi/'
      's0xOn4xHgU2kpDCuE9/u2HFwxcJQZM+ekQNzo3OMSM53IiTZocToVEi82fJRCBi'
      'VuprgR3kpoK9gwQkvoScRNY8qcEhLmQr/qJKoI6jBLLkgdvKJoqAlUtKGy9XBsI5'
      'v9JNV0p5IHFgyAhxP701uHKIQ==';
  static const String _prodExponentB64 = 'AQAB';

  static RSAPublicKey? _cachedKey;

  static RSAPublicKey get _key => _cachedKey ??= _buildPublicKey(_prodModulusB64, _prodExponentB64);

  static BigInt _bytesToBigInt(Uint8List bytes) {
    var result = BigInt.zero;
    for (final b in bytes) {
      result = (result << 8) | BigInt.from(b);
    }
    return result;
  }

  static RSAPublicKey _buildPublicKey(String modulusB64, String exponentB64) {
    final n = _bytesToBigInt(base64Decode(modulusB64));
    final e = _bytesToBigInt(base64Decode(exponentB64));
    return RSAPublicKey(n, e);
  }

  static Uint8List _pkcs7Pad(Uint8List data, [int blockSize = 16]) {
    final padLen = blockSize - (data.length % blockSize);
    final out = Uint8List(data.length + padLen);
    out.setRange(0, data.length, data);
    out.fillRange(data.length, out.length, padLen);
    return out;
  }

  static Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(List<int>.generate(length, (_) => random.nextInt(256)));
  }

  /// Encrypt a request body the same way the myTNB mobile app does:
  /// 1. JSON-serialize [data].
  /// 2. Generate a random AES-256 key + IV.
  /// 3. AES-256-CBC encrypt the JSON (PKCS7 padded) -> `ae`.
  /// 4. RSA-OAEP(SHA-1) encrypt the AES key under TNB's public key -> `ak`.
  /// 5. Base64 the IV -> `av`.
  static MyTnbEncryptedPayload encryptRequest(Object? data) {
    final plaintext = utf8.encode(jsonEncode(data));
    final aesKey = _randomBytes(32);
    final iv = _randomBytes(16);

    final padded = _pkcs7Pad(Uint8List.fromList(plaintext));
    final cbc = CBCBlockCipher(AESEngine())..init(true, ParametersWithIV(KeyParameter(aesKey), iv));
    final ciphertext = Uint8List(padded.length);
    for (var offset = 0; offset < padded.length; offset += cbc.blockSize) {
      cbc.processBlock(padded, offset, ciphertext, offset);
    }

    final oaep = OAEPEncoding(RSAEngine())..init(true, PublicKeyParameter<RSAPublicKey>(_key));
    final encryptedKey = oaep.process(aesKey);

    return MyTnbEncryptedPayload(
      ae: base64Encode(ciphertext),
      ak: base64Encode(encryptedKey),
      av: base64Encode(iv),
    );
  }

  /// RFC-4122 version-4 UUID, upper-cased to match the format TNB's mobile
  /// app sends for `deviceId` / `SecureKey`.
  static String generateUuidV4() {
    final bytes = _randomBytes(16);
    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;
    String hex(int start, int end) =>
        bytes.sublist(start, end).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}'.toUpperCase();
  }
}

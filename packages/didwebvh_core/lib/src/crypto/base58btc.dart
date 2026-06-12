import 'dart:typed_data';

/// Base58 (Bitcoin alphabet) encoding with optional Multibase `z`-prefix
/// framing, as used throughout the did:webvh spec for SCIDs, entry hashes, and
/// `publicKeyMultibase` values.
///
/// Faithful port of the Java `Base58Btc`. The Java side delegates to
/// novacrypto's `Base58`; that, in turn, is the bitcoinj algorithm, which is
/// reimplemented here (the same byte-exact leading-zero handling) to avoid an
/// extra dependency, as allowed by the porting decisions.
class Base58Btc {
  Base58Btc._();

  static const String _alphabet =
      '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
  static const String _multibasePrefix = 'z';

  /// Reverse lookup table: code unit -> base58 digit value (or -1).
  static final Int8List _indexes = _buildIndexes();

  static Int8List _buildIndexes() {
    final indexes = Int8List(128)..fillRange(0, 128, -1);
    for (var i = 0; i < _alphabet.length; i++) {
      indexes[_alphabet.codeUnitAt(i)] = i;
    }
    return indexes;
  }

  /// Encodes [data] as a base58btc string.
  static String encode(List<int> data) {
    if (data.isEmpty) {
      return '';
    }
    // Count leading zero bytes.
    var zeros = 0;
    while (zeros < data.length && data[zeros] == 0) {
      zeros++;
    }
    // Convert base-256 to base-58 in place on a working copy.
    final input = Uint8List.fromList(data);
    final encoded = Uint8List(input.length * 2);
    var outputStart = encoded.length;
    for (var inputStart = zeros; inputStart < input.length;) {
      encoded[--outputStart] = _divmod(input, inputStart, 256, 58);
      if (input[inputStart] == 0) {
        inputStart++; // optimization: skip leading zeros produced by divmod
      }
    }
    // Preserve exactly as many leading '1's as there were leading zero bytes.
    while (outputStart < encoded.length && encoded[outputStart] == 0) {
      outputStart++;
    }
    while (--zeros >= 0) {
      encoded[--outputStart] = 0;
    }
    final out = StringBuffer();
    for (var i = outputStart; i < encoded.length; i++) {
      out.write(_alphabet[encoded[i]]);
    }
    return out.toString();
  }

  /// Decodes a base58btc string [encoded] back to bytes.
  static Uint8List decode(String encoded) {
    if (encoded.isEmpty) {
      return Uint8List(0);
    }
    // Map characters to base58 digit values.
    final input58 = Uint8List(encoded.length);
    for (var i = 0; i < encoded.length; i++) {
      final c = encoded.codeUnitAt(i);
      final digit = c < 128 ? _indexes[c] : -1;
      if (digit < 0) {
        throw FormatException(
          'Invalid base58 character ${String.fromCharCode(c)}',
          encoded,
          i,
        );
      }
      input58[i] = digit;
    }
    // Count leading zeros (base58 '1' characters).
    var zeros = 0;
    while (zeros < input58.length && input58[zeros] == 0) {
      zeros++;
    }
    // Convert base-58 to base-256.
    final decoded = Uint8List(encoded.length);
    var outputStart = decoded.length;
    for (var inputStart = zeros; inputStart < input58.length;) {
      decoded[--outputStart] = _divmod(input58, inputStart, 58, 256);
      if (input58[inputStart] == 0) {
        inputStart++;
      }
    }
    // Skip extra leading zero bytes produced by the conversion.
    while (outputStart < decoded.length && decoded[outputStart] == 0) {
      outputStart++;
    }
    return Uint8List.fromList(
      decoded.sublist(outputStart - zeros, decoded.length),
    );
  }

  /// Encodes [data] with the multibase base58btc `z` prefix.
  static String encodeMultibase(List<int> data) {
    return _multibasePrefix + encode(data);
  }

  /// Decodes a multibase base58btc string, requiring the `z` prefix.
  static Uint8List decodeMultibase(String multibase) {
    if (multibase.isEmpty || multibase[0] != _multibasePrefix) {
      throw ArgumentError(
        "Expected multibase base58btc prefix 'z', got: "
        '${multibase.isEmpty ? '<empty>' : multibase[0]}',
      );
    }
    return decode(multibase.substring(1));
  }

  /// Divides [number] (a big-endian base-[base] integer starting at
  /// [firstDigit]) by [divisor] in place, returning the remainder.
  static int _divmod(Uint8List number, int firstDigit, int base, int divisor) {
    var remainder = 0;
    for (var i = firstDigit; i < number.length; i++) {
      final digit = number[i] & 0xFF;
      final temp = remainder * base + digit;
      number[i] = temp ~/ divisor;
      remainder = temp % divisor;
    }
    return remainder;
  }
}

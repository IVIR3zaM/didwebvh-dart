import 'dart:convert';
import 'dart:typed_data';

import 'package:didwebvh_core/src/core/exceptions.dart';

/// JSON Canonicalization Scheme (RFC 8785) helper. Used everywhere the spec
/// requires a deterministic byte representation of a JSON value — entry-hash
/// input, proof-input, and the SCID placeholder step.
///
/// Faithful port of the Java `Jcs` wrapper, which delegates to erdtman's
/// `JsonCanonicalizer`. The canonicalization itself is reimplemented here
/// line-for-line against RFC 8785:
///  - recursive lexicographic key sorting by **UTF-16 code unit**,
///  - ECMAScript `Number` serialization (RFC 8785 §3.2.2.3 / ES `Number::toString`),
///  - minimal string escaping (RFC 8785 §3.2.2.2),
///  - UTF-8 output.
///
/// **Do not** use the pub.dev `canonical_json` package — it implements the OLPC
/// canonical form, not RFC 8785, and would silently break interop.
class Jcs {
  Jcs._();

  /// Canonicalizes a JSON document supplied as a [json] string and returns the
  /// canonical UTF-8 bytes.
  static Uint8List canonicalize(String json) {
    final Object? parsed;
    try {
      parsed = jsonDecode(json);
    } on FormatException catch (e) {
      throw ValidationException('JCS canonicalization failed: ${e.message}', e);
    }
    final out = StringBuffer();
    _serialize(parsed, out);
    return Uint8List.fromList(utf8.encode(out.toString()));
  }

  static void _serialize(Object? value, StringBuffer out) {
    if (value == null) {
      out.write('null');
    } else if (value is bool) {
      out.write(value ? 'true' : 'false');
    } else if (value is num) {
      out.write(_serializeNumber(value));
    } else if (value is String) {
      _serializeString(value, out);
    } else if (value is List) {
      _serializeArray(value, out);
    } else if (value is Map) {
      _serializeObject(value, out);
    } else {
      throw ValidationException(
        'JCS canonicalization failed: unsupported value type '
        '${value.runtimeType}',
      );
    }
  }

  static void _serializeArray(List<Object?> array, StringBuffer out) {
    out.write('[');
    for (var i = 0; i < array.length; i++) {
      if (i > 0) {
        out.write(',');
      }
      _serialize(array[i], out);
    }
    out.write(']');
  }

  static void _serializeObject(Map<Object?, Object?> object, StringBuffer out) {
    final keys = object.keys.map((k) => k! as String).toList()
      ..sort(_compareByCodeUnit);
    out.write('{');
    for (var i = 0; i < keys.length; i++) {
      if (i > 0) {
        out.write(',');
      }
      _serializeString(keys[i], out);
      out.write(':');
      _serialize(object[keys[i]], out);
    }
    out.write('}');
  }

  /// Compares two strings by UTF-16 code unit, as RFC 8785 (and ECMAScript
  /// `Array.prototype.sort` over the property keys) requires.
  static int _compareByCodeUnit(String a, String b) {
    final shorter = a.length < b.length ? a.length : b.length;
    for (var i = 0; i < shorter; i++) {
      final diff = a.codeUnitAt(i) - b.codeUnitAt(i);
      if (diff != 0) {
        return diff;
      }
    }
    return a.length - b.length;
  }

  static void _serializeString(String value, StringBuffer out) {
    out.write('"');
    for (final unit in value.codeUnits) {
      switch (unit) {
        case 0x22: // "
          out.write(r'\"');
        case 0x5C: // \
          out.write(r'\\');
        case 0x08: // backspace
          out.write(r'\b');
        case 0x09: // tab
          out.write(r'\t');
        case 0x0A: // line feed
          out.write(r'\n');
        case 0x0C: // form feed
          out.write(r'\f');
        case 0x0D: // carriage return
          out.write(r'\r');
        default:
          if (unit < 0x20) {
            out
              ..write(r'\u')
              ..write(unit.toRadixString(16).padLeft(4, '0'));
          } else {
            out.writeCharCode(unit);
          }
      }
    }
    out.write('"');
  }

  /// Serializes a JSON number per ECMAScript `Number::toString`, matching
  /// erdtman's ES6 number serialization (RFC 8785 §3.2.2.3).
  ///
  /// Every JSON number is treated as an IEEE-754 double (as erdtman does),
  /// so integers outside the 2^53 safe range round exactly as they would in
  /// Java; did:webvh log entries only ever carry small integers.
  static String _serializeNumber(num value) {
    final d = value.toDouble();
    if (d == 0) {
      return '0'; // normalizes -0 to 0
    }
    final negative = d < 0;
    final abs = negative ? -d : d;

    // Shortest exponential form, e.g. "1.5e+2" / "1e-7"; split into the
    // significant digit string and the decimal exponent.
    final exponential = abs.toStringAsExponential();
    final eIndex = exponential.indexOf('e');
    final digits = exponential.substring(0, eIndex).replaceFirst('.', '');
    final e = int.parse(exponential.substring(eIndex + 1));

    final k = digits.length; // number of significant digits
    final n = e + 1; // position of the decimal point (ES spec's n)

    final out = StringBuffer();
    if (negative) {
      out.write('-');
    }
    if (k <= n && n <= 21) {
      out
        ..write(digits)
        ..write('0' * (n - k));
    } else if (0 < n && n <= 21) {
      out
        ..write(digits.substring(0, n))
        ..write('.')
        ..write(digits.substring(n));
    } else if (-6 < n && n <= 0) {
      out
        ..write('0.')
        ..write('0' * -n)
        ..write(digits);
    } else {
      if (k == 1) {
        out.write(digits);
      } else {
        out
          ..write(digits[0])
          ..write('.')
          ..write(digits.substring(1));
      }
      final exp = n - 1;
      out
        ..write('e')
        ..write(exp >= 0 ? '+' : '-')
        ..write(exp.abs());
    }
    return out.toString();
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:didwebvh_core/src/core/exceptions.dart';
import 'package:didwebvh_core/src/resolve/remote_did_fetcher.dart';
import 'package:http/http.dart' as http;

/// Fetches did:webvh resolution artifacts over HTTP(S).
///
/// Faithful port of the Java `HttpDidFetcher`. The 200 KB response cap is an
/// implementation safety limit (not a did:webvh spec rule): the body is
/// streamed and rejected **while reading** — before the whole response is
/// buffered — so a malicious endpoint cannot force unbounded memory use, even
/// if it lies about (or omits) `Content-Length`. This mirrors Java/OkHttp's
/// streamed rejection.
final class HttpDidFetcher implements RemoteDidFetcher {
  /// Creates a fetcher with the given [timeout] and [maxResponseSize].
  ///
  /// An optional [client] may be injected for testing; when omitted a default
  /// `http.Client` is created. Throws [ArgumentError] if [timeout] is not
  /// positive or [maxResponseSize] is less than 1.
  HttpDidFetcher({
    Duration timeout = defaultTimeout,
    int maxResponseSize = defaultMaxResponseSize,
    http.Client? client,
  })  : _timeout = timeout,
        _maxResponseSize = maxResponseSize,
        _client = client ?? http.Client() {
    if (timeout.isNegative || timeout == Duration.zero) {
      throw ArgumentError.value(timeout, 'timeout', 'must be positive');
    }
    if (maxResponseSize < 1) {
      throw ArgumentError.value(
        maxResponseSize,
        'maxResponseSize',
        'must be positive',
      );
    }
  }

  /// The default read/connect/call timeout (10 seconds).
  static const Duration defaultTimeout = Duration(seconds: 10);

  /// The default maximum response body size (200 KB).
  static const int defaultMaxResponseSize = 200 * 1024;

  final http.Client _client;
  final Duration _timeout;
  final int _maxResponseSize;

  /// The configured read/connect/call timeout.
  Duration get timeout => _timeout;

  /// The maximum allowed response body size in bytes.
  int get maxResponseSize => _maxResponseSize;

  @override
  Future<String> fetchDidLog(String httpsUrl) => _fetch(httpsUrl, 'did log');

  @override
  Future<String> fetchWitnessProofs(String witnessUrl) =>
      _fetch(witnessUrl, 'witness proofs');

  Future<String> _fetch(String url, String label) async {
    final uri = Uri.parse(url);
    try {
      // The timeout bounds the entire call (connect, headers, and body read),
      // mirroring OkHttp's callTimeout.
      return await _fetchBounded(uri, label).timeout(_timeout);
    } on ResolutionException {
      rethrow;
    } on TimeoutException catch (e) {
      throw ResolutionException.withError(
        'Unable to fetch $label: ${e.message ?? 'request timed out'}',
        'httpError',
        e,
      );
    } on Exception catch (e) {
      throw ResolutionException.withError(
        'Unable to fetch $label: $e',
        'httpError',
        e,
      );
    }
  }

  Future<String> _fetchBounded(Uri uri, String label) async {
    final streamed = await _client.send(http.Request('GET', uri));

    final status = streamed.statusCode;
    if (status < 200 || status >= 300) {
      final error = status == 404 ? 'notFound' : 'httpError';
      throw ResolutionException.withError(
        'Unable to fetch $label: HTTP $status',
        error,
      );
    }

    // Short-circuit on a declared length that already exceeds the cap.
    final declaredLength = streamed.contentLength;
    if (declaredLength != null && declaredLength > _maxResponseSize) {
      throw _tooLarge(label);
    }

    final builder = BytesBuilder(copy: false);
    var total = 0;
    await for (final chunk in streamed.stream) {
      total += chunk.length;
      if (total > _maxResponseSize) {
        throw _tooLarge(label);
      }
      builder.add(chunk);
    }
    return utf8.decode(builder.takeBytes());
  }

  ResolutionException _tooLarge(String label) => ResolutionException.withError(
        'Unable to fetch $label: response exceeds $_maxResponseSize bytes',
        'httpError',
      );
}

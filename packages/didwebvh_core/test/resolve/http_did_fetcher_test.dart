import 'dart:convert';

import 'package:didwebvh_core/didwebvh_core.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Port of Java `HttpDidFetcherTest` (using `MockClient` instead of a real
/// `MockWebServer`, per docs/PORTING-DECISIONS.md).
void main() {
  const url = 'https://example.com/.well-known/did.jsonl';

  test('fetchDidLogReturnsBody', () async {
    final fetcher = HttpDidFetcher(
      client: MockClient((_) async => http.Response('line1\nline2', 200)),
    );
    expect(await fetcher.fetchDidLog(url), 'line1\nline2');
  });

  test('notFoundThrowsResolutionException', () async {
    final fetcher = HttpDidFetcher(
      client: MockClient((_) async => http.Response('', 404)),
    );
    await expectLater(
      fetcher.fetchDidLog(url),
      throwsA(
        isA<ResolutionException>().having((e) => e.error, 'error', 'notFound'),
      ),
    );
  });

  test('responseLargerThanLimitThrows', () async {
    final fetcher = HttpDidFetcher(
      timeout: const Duration(seconds: 1),
      maxResponseSize: 5,
      client: MockClient((_) async => http.Response('123456', 200)),
    );
    await expectLater(
      fetcher.fetchDidLog(url),
      throwsA(
        isA<ResolutionException>()
            .having((e) => e.message, 'message', contains('exceeds')),
      ),
    );
  });

  test('timeoutThrowsResolutionException', () async {
    final fetcher = HttpDidFetcher(
      timeout: const Duration(milliseconds: 50),
      maxResponseSize: 1024,
      client: MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        return http.Response('slow', 200);
      }),
    );
    await expectLater(
      fetcher.fetchDidLog(url),
      throwsA(
        isA<ResolutionException>().having((e) => e.error, 'error', 'httpError'),
      ),
    );
  });

  test('rejectsNonPositiveTimeout', () {
    expect(
      () => HttpDidFetcher(timeout: Duration.zero),
      throwsArgumentError,
    );
    expect(
      () => HttpDidFetcher(timeout: const Duration(seconds: -1)),
      throwsArgumentError,
    );
  });

  test('rejectsNonPositiveMaxResponseSize', () {
    expect(() => HttpDidFetcher(maxResponseSize: 0), throwsArgumentError);
  });

  test('streamingBodyIsRejectedBeforeFullyBuffered', () async {
    // A hostile endpoint that omits Content-Length and streams more bytes than
    // the cap. The fetcher must abort while reading (after ~maxResponseSize),
    // never buffering the full body. We emit chunks lazily and assert the read
    // stops early.
    const cap = 100;
    var emitted = 0;
    Stream<List<int>> hostileBody() async* {
      while (true) {
        emitted += 50;
        yield List<int>.filled(50, 0x61);
      }
    }

    final fetcher = HttpDidFetcher(
      maxResponseSize: cap,
      // No content-length header: forces the streamed (not header) rejection.
      client: MockClient.streaming((request, bodyStream) async {
        return http.StreamedResponse(hostileBody(), 200);
      }),
    );

    await expectLater(
      fetcher.fetchDidLog(url),
      throwsA(
        isA<ResolutionException>()
            .having((e) => e.message, 'message', contains('exceeds'))
            .having((e) => e.error, 'error', 'httpError'),
      ),
    );
    // The generator was aborted shortly after crossing the cap, not forever.
    expect(emitted, lessThanOrEqualTo(cap + 50));
  });

  test('rejectsOnDeclaredContentLengthOverCap', () async {
    final fetcher = HttpDidFetcher(
      maxResponseSize: 5,
      client: MockClient.streaming((request, bodyStream) async {
        return http.StreamedResponse(
          Stream.value(utf8.encode('123456')),
          200,
          contentLength: 6,
        );
      }),
    );
    await expectLater(
      fetcher.fetchDidLog(url),
      throwsA(
        isA<ResolutionException>()
            .having((e) => e.message, 'message', contains('exceeds')),
      ),
    );
  });
}

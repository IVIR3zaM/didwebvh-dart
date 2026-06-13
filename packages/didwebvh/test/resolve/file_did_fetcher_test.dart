import 'dart:io';

import 'package:didwebvh/didwebvh.dart';
import 'package:didwebvh/src/resolve/file_did_fetcher.dart';
import 'package:test/test.dart';

/// Port of Java `FileDidFetcherTest`.
void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('file_did_fetcher'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('fetchDidLogReadsFile', () {
    final log = File('${tmp.path}/did.jsonl')..writeAsStringSync('hello');
    expect(FileDidFetcher().fetchDidLog(log.path), 'hello');
  });

  test('fetchWitnessProofsReadsFile', () {
    final proofs = File('${tmp.path}/witness.json')..writeAsStringSync('{}');
    expect(FileDidFetcher().fetchWitnessProofs(proofs.path), '{}');
  });

  test('fetchDidLogRejectsNullPath', () {
    expect(
      () => FileDidFetcher().fetchDidLog(null),
      throwsA(
        isA<ResolutionException>()
            .having(
              (e) => e.message,
              'message',
              contains('did log path is required'),
            )
            .having((e) => e.error, 'error', 'invalidDid'),
      ),
    );
  });

  test('fetchWitnessProofsRejectsNullPath', () {
    expect(
      () => FileDidFetcher().fetchWitnessProofs(null),
      throwsA(
        isA<ResolutionException>()
            .having(
              (e) => e.message,
              'message',
              contains('witness proofs path is required'),
            )
            .having((e) => e.error, 'error', 'invalidDid'),
      ),
    );
  });

  test('fetchDidLogMapsMissingFileToNotFound', () {
    expect(
      () => FileDidFetcher().fetchDidLog('${tmp.path}/nope.jsonl'),
      throwsA(
        isA<ResolutionException>()
            .having(
              (e) => e.message,
              'message',
              contains('Unable to read did log'),
            )
            .having((e) => e.error, 'error', 'notFound'),
      ),
    );
  });

  test('fetchWitnessProofsMapsMissingFileToNotFound', () {
    expect(
      () => FileDidFetcher().fetchWitnessProofs('${tmp.path}/nope.json'),
      throwsA(
        isA<ResolutionException>()
            .having(
              (e) => e.message,
              'message',
              contains('Unable to read witness proofs'),
            )
            .having((e) => e.error, 'error', 'notFound'),
      ),
    );
  });
}

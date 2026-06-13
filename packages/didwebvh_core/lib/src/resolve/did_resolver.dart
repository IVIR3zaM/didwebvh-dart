import 'package:didwebvh_core/src/core/exceptions.dart';
import 'package:didwebvh_core/src/model/resolve_result.dart';
import 'package:didwebvh_core/src/resolve/file_did_fetcher.dart';
import 'package:didwebvh_core/src/resolve/http_did_fetcher.dart';
import 'package:didwebvh_core/src/resolve/log_processor.dart';
import 'package:didwebvh_core/src/resolve/remote_did_fetcher.dart';
import 'package:didwebvh_core/src/resolve/resolve_options.dart';
import 'package:didwebvh_core/src/url/did_to_https_transformer.dart';
import 'package:didwebvh_core/src/url/did_webvh_url.dart';

/// High-level did:webvh resolver for HTTP, file, and in-memory logs.
///
/// Faithful port of the Java `DidResolver`. Resolution is `async` (the
/// documented ripple from the async `Signer`/validators).
class DidResolver {
  /// Creates a resolver with HTTP settings (default 10 s timeout, 200 KB
  /// response limit). Override [timeout] and/or [maxResponseSize] to customize
  /// the HTTP fetcher.
  DidResolver({Duration? timeout, int? maxResponseSize})
      : this._(
          HttpDidFetcher(
            timeout: timeout ?? HttpDidFetcher.defaultTimeout,
            maxResponseSize:
                maxResponseSize ?? HttpDidFetcher.defaultMaxResponseSize,
          ),
          FileDidFetcher(),
          LogProcessor(),
        );

  /// Creates a resolver with explicit collaborators (test seam).
  DidResolver.withFetchers(
    RemoteDidFetcher httpFetcher,
    FileDidFetcher fileFetcher,
    LogProcessor logProcessor,
  ) : this._(httpFetcher, fileFetcher, logProcessor);

  DidResolver._(this._httpFetcher, this._fileFetcher, this._logProcessor);

  final RemoteDidFetcher _httpFetcher;
  final FileDidFetcher _fileFetcher;
  final LogProcessor _logProcessor;

  /// Resolves a did:webvh DID over HTTPS.
  ///
  /// [did] may include query parameters (`?versionId=...`). [options] supplies
  /// version selection and witness fetch configuration.
  Future<ResolveResult> resolve(String did, [ResolveOptions? options]) async {
    final parsed = DidWebVhUrl.parse(did);
    final baseDid = parsed.toBaseDid();
    final effectiveOptions = (options ?? ResolveOptions.defaults())
        .withFallbacks(_optionsFromQuery(parsed.queryParams));
    if (effectiveOptions.hasMultipleVersionSelectors) {
      throw ResolutionException.withError(
        'Only one of versionId, versionTime, and versionNumber may be used',
        'invalidDid',
      );
    }

    final didLog = await _httpFetcher
        .fetchDidLog(DidToHttpsTransformer.toHttpsUrl(baseDid));
    String? witness;
    if (effectiveOptions.witnessFetchModeValue == WitnessFetchMode.proactive) {
      witness = await _fetchWitnessIfPresent(baseDid);
    }
    return _logProcessor.process(
      didLog,
      witness,
      baseDid,
      effectiveOptions,
      () => _fetchRequiredWitness(baseDid),
    );
  }

  /// Resolves a DID log from a local file without any network access.
  Future<ResolveResult> resolveFromFile(String didLogPath) {
    return _logProcessor.process(
      _fileFetcher.fetchDidLog(didLogPath),
      null,
      null,
      ResolveOptions.defaults(),
    );
  }

  /// Resolves a DID from an in-memory JSONL log string.
  ///
  /// [did] is validated against the log, or `null` to skip the DID check.
  Future<ResolveResult> resolveFromLog(
    String rawJsonl,
    String? did, [
    ResolveOptions? options,
  ]) {
    return _logProcessor.process(
      rawJsonl,
      null,
      did,
      options ?? ResolveOptions.defaults(),
    );
  }

  Future<String?> _fetchWitnessIfPresent(String did) async {
    try {
      return await _httpFetcher
          .fetchWitnessProofs(DidToHttpsTransformer.toWitnessUrl(did));
    } on ResolutionException catch (e) {
      if (e.error == 'notFound') {
        return null;
      }
      rethrow;
    }
  }

  Future<String?> _fetchRequiredWitness(String did) async {
    try {
      return await _httpFetcher
          .fetchWitnessProofs(DidToHttpsTransformer.toWitnessUrl(did));
    } on ResolutionException catch (e) {
      if (e.error == 'notFound') {
        throw ResolutionException.withError(
          'Witness proofs are required but were not found',
          'invalidDid',
          e,
        );
      }
      rethrow;
    }
  }

  ResolveOptions _optionsFromQuery(Map<String, String> queryParams) {
    String? versionId;
    String? versionTime;
    int? versionNumber;
    if (queryParams.containsKey('versionId')) {
      versionId = queryParams['versionId'];
    }
    if (queryParams.containsKey('versionTime')) {
      versionTime = queryParams['versionTime'];
    }
    if (queryParams.containsKey('versionNumber')) {
      final raw = queryParams['versionNumber']!;
      versionNumber = int.tryParse(raw);
      if (versionNumber == null) {
        throw ResolutionException.withError(
          'Invalid versionNumber: $raw',
          'invalidDid',
        );
      }
    }
    return ResolveOptions(
      versionId: versionId,
      versionTime: versionTime,
      versionNumber: versionNumber,
    );
  }
}

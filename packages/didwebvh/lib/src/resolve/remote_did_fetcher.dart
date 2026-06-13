/// Fetches did:webvh resolution artifacts from a remote source.
///
/// Faithful port of the Java `RemoteDidFetcher` interface. Per
/// `docs/PORTING-DECISIONS.md`, fetches return a `Future` because the Dart HTTP
/// client (`package:http`) is asynchronous.
abstract interface class RemoteDidFetcher {
  /// Fetches the `did.jsonl` log from the given HTTPS URL.
  Future<String> fetchDidLog(String httpsUrl);

  /// Fetches the `did-witness.json` proof file from the given HTTPS URL.
  Future<String> fetchWitnessProofs(String witnessUrl);
}

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:oauth2/oauth2.dart';

/// An abstract class for storing and retrieving OAuth2 credentials.
///
/// This interface defines the methods required for storing, retrieving, and
/// clearing OAuth2 credentials. Implementations can use different storage
/// mechanisms, such as secure storage, shared preferences, or in-memory storage.
abstract class OAuth2CredentialsStore {
  /// Clears any stored credentials.
  ///
  /// This method should remove any stored credentials from the storage mechanism.
  Future clear();

  /// Stores the provided credentials.
  ///
  /// This method should store the provided [credentials] in the storage mechanism
  /// for later retrieval.
  Future store(Credentials credentials);

  /// Restores previously stored credentials.
  ///
  /// This method should retrieve the stored credentials from the storage mechanism.
  /// Returns `null` if no credentials are stored or if the stored credentials are invalid.
  Future<Credentials?> restore();
}

/// An implementation of [OAuth2CredentialsStore] that uses secure storage.
///
/// This implementation uses [FlutterSecureStorage] to securely store OAuth2
/// credentials on the device. The credentials are stored as a JSON string
/// under a fixed key.
class OAuth2SecureCredentialsStore implements OAuth2CredentialsStore {
  /// The secure storage instance used to store credentials.
  final _store = const FlutterSecureStorage();

  /// The key used to store credentials in the secure storage.
  static const _storeKey = "oauth2";

  /// Stores the provided credentials in secure storage.
  ///
  /// The credentials are converted to a JSON string before storage.
  @override
  Future store(Credentials credentials) async {
    await _store.write(key: _storeKey, value: credentials.toJson());
  }

  /// Restores previously stored credentials from secure storage.
  ///
  /// This method retrieves the stored credentials JSON string from secure storage,
  /// converts it back to a [Credentials] object, and validates it.
  ///
  /// Returns `null` if no credentials are stored, or if the stored credentials
  /// are invalid (missing token endpoint or empty access token).
  @override
  Future<Credentials?> restore() async {
    final json = await _store.read(key: _storeKey);

    if (json == null) {
      return null;
    }

    final credentials = Credentials.fromJson(json);

    if (credentials.tokenEndpoint == null || credentials.accessToken.isEmpty) {
      await clear();
      return null;
    }

    return credentials;
  }

  /// Clears any stored credentials from secure storage.
  ///
  /// This method removes the credentials from secure storage by deleting
  /// the entry with the fixed key.
  @override
  Future clear() async {
    await _store.delete(key: _storeKey);
  }
}

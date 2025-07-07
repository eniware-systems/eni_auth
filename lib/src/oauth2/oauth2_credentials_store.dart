import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:oauth2/oauth2.dart';

abstract class OAuth2CredentialsStore {
  Future clear();

  Future store(Credentials credentials);

  Future<Credentials?> restore();
}

class OAuth2SecureCredentialsStore implements OAuth2CredentialsStore {
  final _store = const FlutterSecureStorage();
  static const _storeKey = "oauth2";

  @override
  Future store(Credentials credentials) async {
    await _store.write(key: _storeKey, value: credentials.toJson());
  }

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

  @override
  Future clear() async {
    await _store.delete(key: _storeKey);
  }
}

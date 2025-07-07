import 'dart:async';

import 'package:async/async.dart';
import 'package:eni_auth/eni_auth.dart';
import 'package:eni_auth/src/oauth2/oauth2_credentials_store.dart';
import 'package:eni_auth/src/oauth2/oauth2_login_flow.dart';
import 'package:eni_config/eni_config.dart';
import 'package:eni_svc/eni_svc.dart';
import 'package:eni_utils/eni_utils.dart';
import 'package:oauth2/oauth2.dart' as oauth2;

class AuthenticationError extends Error {
  String message;

  AuthenticationError(this.message);

  @override
  String toString() => message;
}

class OAuth2LoginFlowListener {
  final Future Function(Uri authorizationUrl)? onOpenAuthorization;

  OAuth2LoginFlowListener({this.onOpenAuthorization});
}

typedef OAuth2CreateUserCallback<TUser extends AuthUser> = TUser Function(
    Map<String, dynamic> params);

typedef OAuth2Credentials = oauth2.Credentials;

enum OAuth2LoginState {
  notLoggedIn,
  inLoginProcess,
  loggedIn,
}

/// An [AuthProvider] that implements OAuth2 AuthGrantFlow (OIDC)
/// The redirectUrl of your IAM provider must be set to
/// <baseUrl>/login/oidc/callback.
/// Although this is not a requirement, to speed-up redirection you should
/// entrypoint method (main).
class OAuth2Provider<TUser extends AuthUser, TResource>
    extends AuthProvider<TUser, TResource, OAuth2LoginFlowListener>
    with Service {
  late final Uri _authorizationEndpoint;

  late final Uri _tokenEndpoint;

  late final String _clientId;

  late final String? _clientSecret;

  final OAuth2CredentialsStore _credentialsStore;

  oauth2.Client? _client;

  CancelableOperation? _currentLoginFlow;

  Logger get _logger => loggerFor("OAuth2Provider");

  OAuth2LoginState get state {
    if (_state == OAuth2LoginState.loggedIn) {
      if (_client!.credentials.isExpired) {
        // The client credentials have expired!
        _handleClientExpiration();
        _state = OAuth2LoginState.notLoggedIn;
      }
    }
    return _state;
  }

  OAuth2LoginState _state = OAuth2LoginState.notLoggedIn;

  @override
  TUser? get localUser => _user;

  TUser? _user;

  static const List<String> defaultScopes = [];

  final List<String> _scopes;

  OAuth2Provider(
      {OAuth2CredentialsStore? credentialsStore,
      List<String> scopes = defaultScopes})
      : _credentialsStore = credentialsStore ?? OAuth2SecureCredentialsStore(),
        _scopes = scopes;

  static ServiceDescriptor makeDescriptor<TUser extends AuthUser, TResource>(
          {OAuth2CredentialsStore? credentialsStore,
          List<String> scopes = defaultScopes}) =>
      ServiceDescriptor.from(
          create: (_) => OAuth2Provider<TUser, TResource>(
              credentialsStore: credentialsStore, scopes: scopes),
          name: 'OAuth2Service',
          priority: -9000);

  @override
  bool isResourceGranted(TResource resource) {
    if (state != OAuth2LoginState.loggedIn) {
      return false;
    }

    return true;
  }

  @override
  Future onPreInit(ServiceRegistry services) async {
    _authorizationEndpoint =
        Uri.parse(appConfig.get<String>("auth.authorizationEndpoint"));
    _tokenEndpoint = Uri.parse(appConfig.get<String>("auth.tokenEndpoint"));
    _clientId = appConfig.get<String>("auth.clientId");
    _clientSecret =
        appConfig.getOrNull<String>("auth.clientSecret")?.toString();

    await loginInit(config: appConfig.all);
  }

  @override
  Future<bool> login({OAuth2LoginFlowListener? loginFlowListener}) async {
    if (_state == OAuth2LoginState.inLoginProcess) {
      await logout();
    }

    if (_state == OAuth2LoginState.loggedIn) {
      _logger.w("Already logged in, resetting client credentials");
      _client?.close();
      _client = null;
      _state = OAuth2LoginState.notLoggedIn;
      await _handleClientStateChange(controller);
    }

    final existingCredentials = await _credentialsStore.restore();

    _state = OAuth2LoginState.inLoginProcess;

    final config = <String, dynamic>{}; // TODO

    final grant = oauth2.AuthorizationCodeGrant(
        _clientId, _authorizationEndpoint, _tokenEndpoint,
        secret: _clientSecret);

    try {
      if (existingCredentials == null) {
        _logger.i("Starting authorization flow");
        final op = loginFlow(
            config: config,
            logger: _logger,
            grant: grant,
            scopes: _scopes,
            listener: loginFlowListener);
        _currentLoginFlow = op;
        _client = await op.valueOrCancellation();
        _currentLoginFlow = null;
        if (op.isCanceled) {
          _logger.w("Login has been cancelled");
        }
      } else {
        _logger.i("Refreshing token using existing credentials");
        _client = oauth2.Client(existingCredentials,
            identifier: _clientId, secret: _clientSecret);
        await _client!.refreshCredentials(_scopes);
      }
    } on oauth2.AuthorizationException catch (e) {
      // Something went wrong during authorization. Since this is an unexpected
      // thing to happen (connection drop-out, server issues etc)., treat
      // this as an Exception.
      _client?.close();
      _client = null;
      _state = OAuth2LoginState.notLoggedIn;
      _logger.e("Error during login: $e");
      await _handleClientStateChange(controller);
      throw AuthenticationError("${e.error} (${e.description ?? ""})");
    }

    if (_client == null) {
      // Login failed. This is technically not an error so we don't
      // throw anything here.
      _state = OAuth2LoginState.notLoggedIn;
      _logger.e("Login failed");
      await _handleClientStateChange(controller);
      return false;
    }

    _state = OAuth2LoginState.loggedIn;

    _logger.i("Login succeeded");

    if (_client!.credentials.expiration != null) {
      final expirationTimeout =
          _client!.credentials.expiration!.difference(DateTime.now());
      Future.delayed(expirationTimeout).then((_) => _handleClientExpiration);
      _logger
          .d("Access token will expire at ${_client!.credentials.expiration!}");
    }

    await _handleClientStateChange(controller);

    return true;
  }

  Future _handleClientExpiration() async {
    if (_state == OAuth2LoginState.notLoggedIn) {
      return;
    }

    _logger.w("Access Token is expired, trying refresh");

    try {
      await _client!.refreshCredentials();
    } on oauth2.AuthorizationException catch (e) {
      _logger.e("Error refreshing access token: $e");
      await logout();
    }
  }

  Future refreshCredentials() async {
    await _client!.refreshCredentials();
    await _credentialsStore.store(_client!.credentials);
  }

  Future _handleClientStateChange(
      AuthController<TUser, TResource> controller) async {
    if (_client != null) {
      // Store the credentials, update the user and the token refresh strategy
      final credentials = _client!.credentials;

      _user = controller.onCreateUser({
        "accessToken": credentials.accessToken,
        "idToken": credentials.idToken,
        "canRefresh": credentials.canRefresh,
        "scopes": credentials.scopes,
        "expiration": credentials.expiration,
      });

      await _credentialsStore.store(credentials);
      controller.onLogin?.call(_user!);
    } else {
      // Reset the user and credentials
      if (_user != null) {
        controller.onLogout?.call(_user!);
        _user = null;
      }
      await _credentialsStore.clear();
    }

    notifyListeners();
  }

  @override
  Future logout() async {
    if (_currentLoginFlow != null) {
      _logger.w("Cancelling already ongoing login process");
      await _currentLoginFlow?.cancel();
      _currentLoginFlow = null;
    }

    if (_client == null) {
      return;
    }

    // This is not a logout in the sense of the token being revoked
    // The RFC specifies this here: https://tools.ietf.org/html/rfc7009#section-2.1
    // however, the oauth2 package does not support token revocation and also
    // there seems to be a lot of exceptions from the specs when it comes to
    // supporting this feature (https://github.com/dart-lang/oauth2/issues/67)
    // My suggestion here would be not to support token revocation at all and just
    // discard the token as done below.

    _logger.i("Logging out");
    _client?.close();
    _state = OAuth2LoginState.notLoggedIn;
    _client = null;
    await _handleClientStateChange(controller);
  }
}

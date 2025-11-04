import 'dart:async';

import 'package:async/async.dart';
import 'package:eni_auth/eni_auth.dart';
import 'package:eni_auth/src/oauth2/oauth2_credentials_store.dart';
import 'package:eni_auth/src/oauth2/oauth2_login_flow.dart';
import 'package:eni_config/eni_config.dart';
import 'package:eni_svc/eni_svc.dart';
import 'package:eni_utils/eni_utils.dart';
import 'package:oauth2/oauth2.dart' as oauth2;

/// An error that occurs during authentication.
///
/// This error is thrown when something goes wrong during the authentication
/// process, such as an invalid response from the authorization server or
/// a network error.
class AuthenticationError extends Error {
  /// The error message describing what went wrong.
  String message;

  /// Creates a new [AuthenticationError] with the specified message.
  AuthenticationError(this.message);

  @override
  String toString() => message;
}

/// A listener for OAuth2 login flow events.
///
/// This class allows customizing the login flow by providing callbacks
/// for various events in the login process.
class OAuth2LoginFlowListener {
  /// A callback that is called when the authorization URL is opened.
  ///
  /// This can be used to customize how the authorization URL is presented
  /// to the user, such as opening it in a custom browser or WebView.
  final Future Function(Uri authorizationUrl)? onOpenAuthorization;

  /// Creates a new [OAuth2LoginFlowListener] with the specified callbacks.
  OAuth2LoginFlowListener({this.onOpenAuthorization});
}

/// A callback function type for creating user objects from OAuth2 authentication parameters.
///
/// This is similar to [CreateUserCallback] but specifically for OAuth2 authentication.
typedef OAuth2CreateUserCallback<TUser extends AuthUser> = TUser Function(
    Map<String, dynamic> params);

/// A type alias for OAuth2 credentials.
///
/// This is a convenience alias for the [oauth2.Credentials] class from the oauth2 package.
typedef OAuth2Credentials = oauth2.Credentials;

/// The possible states of the OAuth2 login process.
///
/// This enum represents the different states that the OAuth2 login process
/// can be in at any given time.
enum OAuth2LoginState {
  /// The user is not logged in.
  ///
  /// This is the initial state and the state after logout.
  notLoggedIn,

  /// The login process is in progress.
  ///
  /// This state is active while the user is being redirected to the
  /// authorization server and while waiting for the authorization response.
  inLoginProcess,

  /// The user is logged in.
  ///
  /// This state is active after a successful login.
  loggedIn,
}

/// An [AuthProvider] that implements OAuth2 Authorization Code Flow (OIDC).
///
/// This provider implements the OAuth2 Authorization Code Flow for authentication,
/// which is commonly used for OpenID Connect (OIDC) authentication. It handles
/// the complete authentication flow, including:
///
/// - Authorization code flow
/// - Token refresh
/// - Secure credential storage
/// - Platform-specific login flows (web, mobile, desktop)
///
/// The redirectUrl of your IAM provider must be set to
/// `<baseUrl>/login/oidc/callback`. This is the URL that the authorization
/// server will redirect to after the user has authenticated.
///
/// Configuration is done through the app configuration, with the following keys:
/// - `auth.authorizationEndpoint`: The authorization endpoint URL
/// - `auth.tokenEndpoint`: The token endpoint URL
/// - `auth.clientId`: The client ID
/// - `auth.clientSecret`: The client secret (optional)
/// - `auth.platform.web.redirect_url`: The redirect URL for web platforms
/// - `auth.platform.io.redirect_url`: The redirect URL for native platforms
///
/// Generic type parameters:
/// * [TUser] - The type of user object, must extend [AuthUser]
/// * [TResource] - The type of resource that can be granted to users
class OAuth2Provider<TUser extends AuthUser, TResource>
    extends AuthProvider<TUser, TResource, OAuth2LoginFlowListener>
    with Service {
  /// The authorization endpoint URL.
  ///
  /// This is the URL that the user will be redirected to for authentication.
  late final Uri _authorizationEndpoint;

  /// The token endpoint URL.
  ///
  /// This is the URL that will be used to exchange the authorization code
  /// for an access token.
  late final Uri _tokenEndpoint;

  /// The client ID.
  ///
  /// This is the ID of the client application registered with the authorization server.
  late final String _clientId;

  /// The client secret.
  ///
  /// This is the secret of the client application registered with the authorization server.
  /// It is optional and may be null.
  late final String? _clientSecret;

  /// The credentials store used to store and retrieve OAuth2 credentials.
  final OAuth2CredentialsStore _credentialsStore;

  /// The OAuth2 client used to make authenticated requests.
  ///
  /// This is null if the user is not logged in.
  oauth2.Client? _client;

  /// The current login flow operation.
  ///
  /// This is used to cancel the login flow if needed.
  CancelableOperation? _currentLoginFlow;

  /// The logger used by this provider.
  Logger get _logger => loggerFor("OAuth2Provider");

  /// The current state of the login process.
  ///
  /// This property checks if the credentials have expired and updates the state
  /// accordingly. If the credentials have expired, it attempts to refresh them.
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

  /// The backing field for the [state] property.
  OAuth2LoginState _state = OAuth2LoginState.notLoggedIn;

  /// Returns the current logged in user, or `null` if not logged in.
  @override
  TUser? get localUser => _user;

  /// The backing field for the [localUser] property.
  TUser? _user;

  /// The default scopes to request during authentication.
  ///
  /// This is an empty list by default, meaning no specific scopes are requested.
  static const List<String> defaultScopes = [];

  /// The scopes to request during authentication.
  final List<String> _scopes;

  /// Creates a new [OAuth2Provider] with the specified credentials store and scopes.
  ///
  /// The [credentialsStore] is used to store and retrieve OAuth2 credentials.
  /// If not provided, a default [OAuth2SecureCredentialsStore] is used.
  ///
  /// The [scopes] are the OAuth2 scopes to request during authentication.
  /// If not provided, [defaultScopes] is used.
  OAuth2Provider(
      {OAuth2CredentialsStore? credentialsStore,
      List<String>? scopes = defaultScopes})
      : _credentialsStore = credentialsStore ?? OAuth2SecureCredentialsStore(),
        _scopes = scopes ?? [];

  /// Creates a [ServiceDescriptor] for registering this provider with the service registry.
  ///
  /// This is a convenience method for creating a service descriptor for this provider.
  /// It can be used to register the provider with the service registry manually.
  ///
  /// Example:
  /// ```dart
  /// services.register(OAuth2Provider.makeDescriptor<MyUser, BuildContext>());
  /// ```
  static ServiceDescriptor makeDescriptor<TUser extends AuthUser, TResource>(
          {OAuth2CredentialsStore? credentialsStore,
          List<String> scopes = defaultScopes}) =>
      ServiceDescriptor.from(
          create: (_) => OAuth2Provider<TUser, TResource>(
              credentialsStore: credentialsStore, scopes: scopes),
          name: 'OAuth2Service',
          priority: -9000);

  /// Determines if a user has access to a resource.
  ///
  /// This method checks if the user is logged in. If not, it returns `false`.
  /// Otherwise, it returns `true`, indicating that the resource is granted.
  ///
  /// In a real-world application, you might want to extend this method to check
  /// specific permissions or roles for the resource.
  ///
  /// Returns `true` if the resource is granted, `false` otherwise.
  @override
  bool isResourceGranted(TResource resource) {
    if (state != OAuth2LoginState.loggedIn) {
      return false;
    }

    return true;
  }

  /// Initializes the provider by retrieving configuration from the app config.
  ///
  /// This method is called automatically by the service registry during initialization.
  /// It retrieves the OAuth2 configuration from the app config and initializes
  /// the provider with the appropriate endpoints and credentials.
  ///
  /// Required configuration keys:
  /// - `auth.authorizationEndpoint`: The authorization endpoint URL
  /// - `auth.tokenEndpoint`: The token endpoint URL
  /// - `auth.clientId`: The client ID
  ///
  /// Optional configuration keys:
  /// - `auth.clientSecret`: The client secret
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

  /// Initiates the login process using OAuth2 Authorization Code Flow.
  ///
  /// This method starts the OAuth2 Authorization Code Flow for authentication.
  /// It first checks if there are any existing credentials stored, and if so,
  /// attempts to refresh them. If not, it starts a new authorization flow.
  ///
  /// The method handles various states and errors that can occur during the
  /// authentication process, such as:
  /// - Already being in the login process
  /// - Already being logged in
  /// - Authorization errors
  /// - Login cancellation
  ///
  /// The [loginFlowListener] parameter can be used to provide a listener for
  /// the login flow, which can be used to customize the login experience.
  ///
  /// Returns `true` if login was successful, `false` otherwise.
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

    final grant = oauth2.AuthorizationCodeGrant(
        _clientId, _authorizationEndpoint, _tokenEndpoint,
        secret: _clientSecret);

    try {
      if (existingCredentials == null) {
        _logger.i("Starting authorization flow");
        final op = loginFlow(
            config: appConfig.all,
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

  /// Handles the expiration of the access token.
  ///
  /// This method is called when the access token expires. It attempts to refresh
  /// the token using the refresh token. If the refresh fails, it logs the user out.
  ///
  /// This method is called automatically by the [state] property when it detects
  /// that the credentials have expired.
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

  /// Refreshes the OAuth2 credentials.
  ///
  /// This method refreshes the access token using the refresh token and stores
  /// the updated credentials in the credentials store.
  ///
  /// This can be used to proactively refresh the token before it expires.
  Future refreshCredentials() async {
    await _client!.refreshCredentials();
    await _credentialsStore.store(_client!.credentials);
  }

  /// Handles changes in the client state.
  ///
  /// This method is called when the client state changes, such as when the user
  /// logs in or out. It updates the user object, stores or clears the credentials,
  /// and notifies listeners of the change.
  ///
  /// When the client is not null (user is logged in), it:
  /// - Creates a user object from the credentials
  /// - Stores the credentials in the credentials store
  /// - Calls the onLogin callback
  ///
  /// When the client is null (user is logged out), it:
  /// - Calls the onLogout callback
  /// - Clears the user object
  /// - Clears the credentials from the credentials store
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

  /// Logs out the current user.
  ///
  /// This method ends the current user's session and clears any stored credentials.
  /// If there is an ongoing login process, it cancels it.
  ///
  /// Note: This method does not revoke the token on the authorization server.
  /// It simply discards the token locally. This is because the oauth2 package
  /// does not support token revocation, and there are many exceptions to the
  /// specification when it comes to supporting this feature.
  ///
  /// For more information, see:
  /// - https://tools.ietf.org/html/rfc7009#section-2.1
  /// - https://github.com/dart-lang/oauth2/issues/67
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

    _logger.i("Logging out");
    _client?.close();
    _state = OAuth2LoginState.notLoggedIn;
    _client = null;
    await _handleClientStateChange(controller);
  }
}

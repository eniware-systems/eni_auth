import 'package:eni_auth/eni_auth.dart';
import 'package:flutter/widgets.dart';

/// A callback function type for creating user objects from authentication parameters.
///
/// This is used by [AuthController] to create user objects when authentication succeeds.
typedef CreateUserCallback<TUser extends AuthUser> = TUser Function(
    Map<String, dynamic> params);

/// Controls the authentication process and user creation.
///
/// The [AuthController] is responsible for creating user objects from authentication
/// parameters and handling authentication events (login, logout, resource granting).
///
/// Generic type parameters:
/// * [TUser] - The type of user object, must extend [AuthUser]
/// * [TResource] - The type of resource that can be granted to users
class AuthController<TUser extends AuthUser, TResource> {
  /// Callback function for creating user objects from authentication parameters.
  ///
  /// This is called when authentication succeeds to create a user object from
  /// the authentication parameters.
  late final TUser Function(Map<String, dynamic> params) onCreateUser;

  /// Creates a new [AuthController] with the specified callbacks.
  ///
  /// The [onCreateUser] callback is required and is used to create user objects
  /// from authentication parameters.
  ///
  /// The [onLogin], [onLogout], and [onGrantResource] callbacks are optional and
  /// are called when the corresponding events occur.
  AuthController(
      {required this.onCreateUser,
      this.onLogin,
      this.onLogout,
      this.onGrantResource});

  /// Callback function that is called when a user logs in.
  ///
  /// This is called after authentication succeeds and a user object has been created.
  final void Function(TUser user)? onLogin;

  /// Callback function that is called when a user logs out.
  ///
  /// This is called before the user object is cleared.
  final void Function(TUser user)? onLogout;

  /// Callback function that determines if a user has access to a resource.
  ///
  /// This is called by [AuthProvider.isResourceGranted] to determine if a user
  /// has access to a resource. If this returns `false`, the resource is not granted.
  /// If this is not provided, all resources are granted by default.
  final bool Function(TUser? user, TResource)? onGrantResource;
}

/// A service that provides features for authenticating the app user and
/// managing their permissions and logged in state.
///
/// This is an abstract class that defines the interface for authentication providers.
/// Concrete implementations include [OAuth2Provider] and [DummyAuthProvider].
///
/// Generic type parameters:
/// * [TUser] - The type of user object, must extend [AuthUser]
/// * [TResource] - The type of resource that can be granted to users
/// * [TLoginFlowListener] - The type of listener for the login flow
abstract class AuthProvider<TUser extends AuthUser, TResource,
        TLoginFlowListener> extends ChangeNotifier
    with AuthControllerProvider<TUser, TResource> {
  /// Returns the current logged in local [AuthUser] or null if
  /// not logged in.
  ///
  /// This is used to check if a user is currently authenticated.
  TUser? get localUser;

  /// Determines if a user has access to a resource.
  ///
  /// This is used to check if the current user has access to a specific resource.
  /// The implementation should consider the user's authentication status and
  /// any resource-specific access rules.
  ///
  /// Returns `true` if the resource is granted, `false` otherwise.
  bool isResourceGranted(TResource resource);

  /// Initiates the login process.
  ///
  /// This method starts the authentication process for the user. The specific
  /// implementation depends on the authentication provider.
  ///
  /// The [loginFlowListener] parameter can be used to provide a listener for
  /// the login flow, which can be used to customize the login experience.
  ///
  /// Returns `true` if login was successful, `false` otherwise.
  Future<bool> login({TLoginFlowListener? loginFlowListener});

  /// Logs out the current user.
  ///
  /// This method ends the current user's session and clears any stored credentials.
  Future logout();
}

import 'package:eni_auth/src/auth_user.dart';
import 'package:eni_auth/src/svc/auth_provider.dart';
import 'package:eni_svc/service.dart';
import 'package:flutter/widgets.dart';

/// A mixin that provides access to an [AuthController].
///
/// This mixin is used by [AuthProvider] to access the [AuthController] that
/// was provided to the [AuthService].
mixin AuthControllerProvider<TUser extends AuthUser, TResource> {
  /// The [AuthController] that controls the authentication process.
  AuthController<TUser, TResource> get controller => _controller;

  /// The backing field for the [controller] property.
  late final AuthController<TUser, TResource> _controller;
}

/// A service that manages authentication through an [AuthProvider].
///
/// The [AuthService] is the main entry point for authentication functionality.
/// It delegates most of its work to an [AuthProvider] instance, which it retrieves
/// from the service registry during initialization.
///
/// Generic type parameters:
/// * [TUser] - The type of user object, must extend [AuthUser]
/// * [TResource] - The type of resource that can be granted to users
/// * [TLoginFlowListener] - The type of listener for the login flow
class AuthService<TUser extends AuthUser, TResource, TLoginFlowListener>
    with Service {
  /// The authentication provider that handles the actual authentication.
  late final AuthProvider<TUser, TResource, TLoginFlowListener> _provider;

  /// The controller that manages user creation and authentication events.
  final AuthController<TUser, TResource> _controller;

  /// Creates a new [AuthService] with the specified controller.
  ///
  /// The [controller] is used to create user objects and handle authentication events.
  AuthService({required AuthController<TUser, TResource> controller})
      : _controller = controller;

  /// Initializes the service by retrieving the [AuthProvider] from the service registry.
  ///
  /// This method is called automatically by the service registry during initialization.
  /// It retrieves the [AuthProvider] from the service registry and sets it up with
  /// the [AuthController] that was provided to this service.
  ///
  /// Throws a [StateError] if no [AuthProvider] is found in the service registry.
  @override
  Future onPreInit(ServiceRegistry services) async {
    AuthProvider? provider = services.getServiceOrNull<AuthProvider>(
        requiredRunLevel: RunLevel.created);

    if (provider == null) {
      throw StateError(
          "Could not find an AuthProvider instance. In order to use authentication you will have to provide one via config or manually.");
    }

    _provider = provider as AuthProvider<TUser, TResource, TLoginFlowListener>;
    _provider._controller = _controller;
  }

  /// Determines if a user has access to a resource.
  ///
  /// This method first checks if the resource is granted by the [AuthController]'s
  /// [AuthController.onGrantResource] callback, and then checks if it's granted
  /// by the [AuthProvider]'s [AuthProvider.isResourceGranted] method.
  ///
  /// Returns `true` if the resource is granted, `false` otherwise.
  bool isResourceGranted(resource) =>
      (_controller.onGrantResource?.call(localUser, resource) ?? true) &&
      _provider.isResourceGranted(resource);

  /// Returns the current logged in user, or `null` if not logged in.
  ///
  /// This is a convenience property that delegates to the [AuthProvider]'s
  /// [AuthProvider.localUser] property.
  get localUser => _provider.localUser;

  /// Initiates the login process.
  ///
  /// This method delegates to the [AuthProvider]'s [AuthProvider.login] method.
  /// The specific implementation depends on the authentication provider.
  ///
  /// The [loginFlowListener] parameter can be used to provide a listener for
  /// the login flow, which can be used to customize the login experience.
  ///
  /// Returns `true` if login was successful, `false` otherwise.
  Future<bool> login({loginFlowListener}) =>
      _provider.login(loginFlowListener: loginFlowListener);

  /// Logs out the current user.
  ///
  /// This method delegates to the [AuthProvider]'s [AuthProvider.logout] method.
  /// It ends the current user's session and clears any stored credentials.
  Future logout() => _provider.logout();
}

/// Extension on [BuildContext] that provides easy access to the [AuthService].
///
/// This extension allows you to access the [AuthService] from any widget in the
/// build tree using `context.auth`.
extension BuildContextAuthExtension on BuildContext {
  /// Returns the [AuthService] from the service registry.
  ///
  /// This is a convenience method that retrieves the [AuthService] from the
  /// service registry using the current build context.
  AuthService get auth => getService<AuthService>();
}

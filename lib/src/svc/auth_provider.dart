import 'package:eni_auth/eni_auth.dart';
import 'package:flutter/widgets.dart';

typedef CreateUserCallback<TUser extends AuthUser> = TUser Function(
    Map<String, dynamic> params);

class AuthController<TUser extends AuthUser, TResource> {
  late final TUser Function(Map<String, dynamic> params) onCreateUser;

  AuthController(
      {required this.onCreateUser,
      this.onLogin,
      this.onLogout,
      this.onGrantResource});

  final void Function(TUser user)? onLogin;
  final void Function(TUser user)? onLogout;
  final bool Function(TUser? user, TResource)? onGrantResource;
}

/// A service that provides features for authenticating the app user and
/// managing their permissions and logged in state.
abstract class AuthProvider<TUser extends AuthUser, TResource,
        TLoginFlowListener> extends ChangeNotifier
    with AuthControllerProvider<TUser, TResource> {
  /// Returns the current logged in local [AuthUser] or null if
  /// not logged in.
  TUser? get localUser;

  bool isResourceGranted(TResource resource);

  Future<bool> login({TLoginFlowListener? loginFlowListener});

  Future logout();
}

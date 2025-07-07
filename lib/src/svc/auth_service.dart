import 'package:eni_auth/src/auth_user.dart';
import 'package:eni_auth/src/svc/auth_provider.dart';
import 'package:eni_svc/service.dart';
import 'package:flutter/widgets.dart';

mixin AuthControllerProvider<TUser extends AuthUser, TResource> {
  AuthController<TUser, TResource> get controller => _controller;
  late final AuthController<TUser, TResource> _controller;
}

class AuthService<TUser extends AuthUser, TResource, TLoginFlowListener>
    with Service {
  late final AuthProvider<TUser, TResource, TLoginFlowListener> _provider;

  final AuthController<TUser, TResource> _controller;

  AuthService({required AuthController<TUser, TResource> controller})
      : _controller = controller;

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

  bool isResourceGranted(resource) =>
      (_controller.onGrantResource?.call(localUser, resource) ?? true) &&
      _provider.isResourceGranted(resource);

  get localUser => _provider.localUser;

  Future<bool> login({loginFlowListener}) =>
      _provider.login(loginFlowListener: loginFlowListener);

  Future logout() => _provider.logout();
}

extension BuildContextAuthExtension on BuildContext {
  AuthService get auth => getService<AuthService>();
}

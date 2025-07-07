import 'package:eni_auth/src/auth_user.dart';
import 'package:eni_utils/logger.dart';
import 'package:flutter/scheduler.dart';

import 'auth_provider.dart';

class DummyAuthProvider<TUser extends AuthUser, TResource, TLoginFlowListener>
    extends AuthProvider<TUser, TResource, TLoginFlowListener> {
  @override
  bool isResourceGranted(TResource? resource) => true;

  @override
  TUser? localUser;

  @override
  Future<bool> login({TLoginFlowListener? loginFlowListener}) async {
    if (localUser != null) {
      await logout();
    }

    _logger.i("Dummy Auth Provider logged in");
    localUser = controller.onCreateUser(const {});
    controller.onLogin?.call(localUser!);
    SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
    return true;
  }

  @override
  Future logout() async {
    if (localUser == null) {
      _logger.e("Dummy Auth Provider cannot log out, not logged in");
      return;
    }
    controller.onLogout?.call(localUser!);
    _logger.i("Dummy Auth Provider logged out");
    localUser = null;
    SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
  }

  Logger get _logger => loggerFor("DummyAuthProvider");
}

import 'package:eni_auth/oauth2.dart';
import 'package:eni_auth/src/auth_user.dart';
import 'package:eni_auth/src/svc/auth_service.dart';
import 'package:eni_auth/src/svc/dummy_auth_provider.dart';
import 'package:eni_config/eni_config.dart';
import 'package:eni_svc/eni_svc.dart';

import 'auth_provider.dart';
import 'default_service_configuration.dart';

class _AuthPackage<TUser extends AuthUser, TResource, TLoginFlowListener>
    extends Package {
  final AuthController<TUser, TResource> controller;
  final bool autoConfigure;

  _AuthPackage({required this.controller, required this.autoConfigure});

  @override
  Future onInit(ServiceRegistry services) async {
    if (autoConfigure) {
      final provider =
          appConfig.getOrNull<String>("auth.provider")?.toLowerCase();
      final scopes = appConfig.getOrNull<List<String>>("auth.scopes");

      if (provider == null || provider.isEmpty) {
        throw ArgumentError("auth.provider config is missing");
      }

      if (provider == "oauth2") {
        services.register(ServiceDescriptor.from<AuthProvider>(
            create: (_) => OAuth2Provider<TUser, TResource>(scopes: scopes),
            name: "OAuth2Provider"));
      } else if (provider == "dummy") {
        services.register(ServiceDescriptor.from<AuthProvider>(
            create: (_) =>
                DummyAuthProvider<TUser, TResource, TLoginFlowListener>(),
            name: "DummyAuthProvider"));
      } else {
        throw UnsupportedError("Auth provider $provider is unsupported");
      }
    }

    services.register(ServiceDescriptor.from<AuthService>(
        create: (_) => AuthService<TUser, TResource, TLoginFlowListener>(
            controller: controller),
        name: "AuthService"));
  }

  @override
  String get name => "eni_auth";
}

extension ServiceRegistryAuthExtension on MutableServiceRegistry {
  void addAuth<TUser extends AuthUser, TResource, TLoginFlowListener>(
      {required AuthController<TUser, TResource> controller,
      bool autoConfigure = true}) {
    final package =
        _AuthPackage(controller: controller, autoConfigure: autoConfigure);
    register(ServiceDescriptor.from<Package>(
        name: package.name, create: (_) => package));
    register(ServiceDescriptor.from<ConfigProvider>(
        create: (_) => defaultConfigProvider,
        name: 'DefaultAuthConfigProvider'));
  }
}

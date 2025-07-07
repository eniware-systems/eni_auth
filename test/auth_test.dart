import 'package:eni_auth/eni_auth.dart';
import 'package:eni_svc/eni_svc.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class MyTestUser extends AuthUser {}

class MyAuthProvider extends AuthProvider<MyTestUser, dynamic, dynamic> {
  bool shouldGrantResource = true;

  @override
  bool isResourceGranted(resource) {
    return shouldGrantResource;
  }

  @override
  MyTestUser? localUser;

  @override
  Future<bool> login({loginFlowListener}) async {
    localUser = controller.onCreateUser({});
    return true;
  }

  @override
  Future logout() async {
    localUser = null;
  }
}

void main() {
  testWidgets('login with custom AuthProvider is working', (tester) async {
    late ImmutableServiceRegistry registry;

    final scope = ServiceScope(
      builder: (context, bootstrapLevel) {
        registry = context.services;
        return Container();
      },
    )
      ..addAuth(
          autoConfigure: false,
          controller: AuthController(onCreateUser: (params) => MyTestUser()))
      ..provide<AuthProvider>(MyAuthProvider());

    await tester.pumpWidget(scope);
    final authService = registry.getService<AuthService>();
    expect(authService.localUser, isNull);
    await authService.login();
    expect(authService.localUser, isNotNull);
    await authService.logout();
    expect(authService.localUser, isNull);
  });

  testWidgets('AuthBuilder is working', (tester) async {
    bool wasGranted = false;

    final provider = MyAuthProvider();
    late ImmutableServiceRegistry registry;

    final scope = ServiceScope(
      builder: (context, bootstrapLevel) {
        registry = context.services;
        return AuthBuilder(builder: (context, user) {
          wasGranted = user != null;
          return Container();
        });
      },
    )
      ..addAuth(
          autoConfigure: false,
          controller: AuthController(onCreateUser: (params) => MyTestUser()))
      ..provide<AuthProvider>(provider);

    provider.shouldGrantResource = false;
    await tester.pumpWidget(scope);
    final authService = registry.getService<AuthService>();
    await authService.login();
    expect(wasGranted, isFalse);

    provider.shouldGrantResource = true;
    await tester.pumpAndSettle();
    expect(wasGranted, isTrue);
  });
}

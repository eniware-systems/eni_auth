import 'package:eni_auth/eni_auth.dart';
import 'package:eni_svc/eni_svc.dart';
import 'package:flutter/widgets.dart';

/// The builder callback used by the [AuthBuilder] widget.
typedef AuthBuilderCallback<TUser extends AuthUser> = Function(
    BuildContext context, TUser? user);

/// A builder widget that provides information about the authentication of the
/// current user.
class AuthBuilder<TUser extends AuthUser> extends StatelessWidget {
  const AuthBuilder({super.key, required this.builder});

  final AuthBuilderCallback<TUser> builder;

  @override
  Widget build(BuildContext context) {
    if (context.getServiceOrNull<AuthProvider>() == null) {
      // no auth service is present in the context, skip.
      return builder(context, null);
    }

    return ServiceListener<AuthProvider>(builder: (context, service) {
      if (!service.isResourceGranted(context)) {
        return builder(context, null);
      }
      return builder(context, service.localUser as TUser?);
    });
  }
}

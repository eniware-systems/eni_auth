import 'package:eni_auth/eni_auth.dart';
import 'package:eni_svc/eni_svc.dart';
import 'package:flutter/widgets.dart';

/// The builder callback used by the [AuthBuilder] widget.
///
/// This callback is called with the current [BuildContext] and the authenticated
/// user (or `null` if not authenticated). It should return a widget to display.
typedef AuthBuilderCallback<TUser extends AuthUser> = Function(
    BuildContext context, TUser? user);

/// A builder widget that provides information about the authentication of the
/// current user.
///
/// This widget listens for changes in the authentication state and rebuilds
/// its children when the state changes. It provides the current authenticated
/// user (or `null` if not authenticated) to the [builder] callback.
///
/// Example:
/// ```dart
/// AuthBuilder<MyUser>(
///   builder: (context, user) {
///     if (user == null) {
///       return LoginButton();
///     } else {
///       return UserProfile(user: user);
///     }
///   },
/// )
/// ```
///
/// Generic type parameter:
/// * [TUser] - The type of user object, must extend [AuthUser]
class AuthBuilder<TUser extends AuthUser> extends StatelessWidget {
  /// Creates a new [AuthBuilder] widget.
  ///
  /// The [builder] callback is required and is used to build the widget tree
  /// based on the current authentication state.
  const AuthBuilder({super.key, required this.builder});

  /// The callback that builds the widget tree based on the authentication state.
  ///
  /// This callback is called with the current [BuildContext] and the authenticated
  /// user (or `null` if not authenticated). It should return a widget to display.
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

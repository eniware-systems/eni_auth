/// The base class that describes a user in the authentication system.
///
/// This is an abstract class that should be extended by concrete user implementations.
/// Implementations should provide properties to identify and describe the user,
/// such as an ID, name, email, etc.
///
/// Example:
/// ```dart
/// class MyUser extends AuthUser {
///   final String id;
///   final String name;
///
///   MyUser({required this.id, required this.name});
/// }
/// ```
abstract class AuthUser {}

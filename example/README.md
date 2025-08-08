# ENI Auth Example

This example demonstrates how to use the `eni_auth` package to implement OAuth2 authentication in a Flutter application.

## Features

- OAuth2 authentication flow
- Custom user class implementation
- Login and logout functionality
- UI that responds to authentication state changes
- Error handling

## Getting Started

### Prerequisites

- Flutter SDK (>=3.32.0)
- Dart SDK (>=3.0.0)

### Configuration

Before running the example, you need to update the OAuth2 configuration in `lib/main.dart` with your own OAuth2 provider details:

```dart
final config = {
  'auth': {
    'provider': 'dummy', // Using DummyAuthProvider for simplicity in this example
    // The following settings are only needed for OAuth2 provider
    'authorizationEndpoint': 'https://your-auth-server.com/oauth2/authorize', // Replace with your authorization endpoint
    'tokenEndpoint': 'https://your-auth-server.com/oauth2/token', // Replace with your token endpoint
    'clientId': 'your-client-id', // Replace with your client ID
    'clientSecret': 'your-client-secret', // Replace with your client secret
    'scopes': ['openid', 'profile', 'email'], // Adjust scopes as needed
    'platform': {
      'web': {'redirect_url': '/login/oidc/callback'},
      'io': {'redirect_url': 'http://localhost:9004/login/oidc/callback'}
    }
  }
};
```

### Running the Example

1. Clone the repository
2. Navigate to the example directory
3. Run `flutter pub get` to install dependencies
4. Run `flutter run` to start the application

## Understanding the Example

### Custom User Class

The example defines a custom user class `MyUser` that extends `AuthUser`:

```dart
class MyUser extends AuthUser {
  final String id;
  final String name;
  final String email;

  MyUser({
    required this.id,
    required this.name,
    required this.email,
  });

  factory MyUser.fromOAuth2(Map<String, dynamic> params) {
    return MyUser(
      id: params['sub'] ?? '',
      name: params['name'] ?? '',
      email: params['email'] ?? '',
    );
  }
}
```

### Authentication Setup

The example sets up authentication by:

1. Creating a ServiceScope widget
2. Configuring authentication settings
3. Creating an auth controller with callbacks for login, logout, and resource access
4. Providing services to the ServiceScope

```dart
// Create an auth controller that knows how to create MyUser objects
final authController = AuthController<MyUser, BuildContext>(
  onCreateUser: MyUser.fromOAuth2,
  onLogin: (user) {
    print('User logged in: $user');
  },
  onLogout: (user) {
    print('User logged out: $user');
  },
  onGrantResource: (user, resource) {
    // You can implement custom resource access control here
    return true; // Allow access to all resources
  },
);

// Use ServiceScope to provide services
return ServiceScope(
  builder: (context, bootstrapLevel) {
    // Only show the app when services are ready
    if (bootstrapLevel != RunLevel.ready) {
      return const CircularProgressIndicator();
    }
    
    return YourApp(); // Your main app widget
  },
)..provide<ConfigProvider>(MemoryConfigProvider(config: config))
  ..provide<Package>(
    _AuthPackageProvider(
      controller: authController,
      autoConfigure: true,
    ),
  );
```

The example uses a helper class to provide the auth package:

```dart
// Helper class to provide the auth package
class _AuthPackageProvider extends Package {
  final AuthController<MyUser, BuildContext> controller;
  final bool autoConfigure;

  _AuthPackageProvider({required this.controller, required this.autoConfigure});

  @override
  Future onInit(ServiceRegistry services) async {
    services.addAuth<MyUser, BuildContext, OAuth2LoginFlowListener>(
      controller: controller,
      autoConfigure: autoConfigure,
    );
  }

  @override
  String get name => "eni_auth_example";
}
```

### UI with AuthBuilder

The example uses the `AuthBuilder` widget to build UI based on authentication state:

```dart
AuthBuilder<MyUser>(
  builder: (context, user) {
    if (user == null) {
      // User is not authenticated
      return LoginButton();
    } else {
      // User is authenticated
      return UserProfile(user: user);
    }
  },
)
```

## Additional Resources

For more information about the `eni_auth` package, see the [package documentation](../README.md).
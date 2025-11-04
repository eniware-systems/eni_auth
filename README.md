# eni_auth - Eniware Authentication

The `eni_auth` package provides a comprehensive OAuth2 authentication solution for Flutter applications. It enables users to authenticate via OAuth2 (e.g., OpenID Connect), manages the login flow, stores and refreshes access tokens, and provides authentication information to other parts of the application. It also supports secure credential storage and automatic token refresh.

---

## Features

- **OAuth2 Authentication** — Complete implementation of OAuth2 Authorization Code Flow (OIDC)
- **Secure Credential Storage** — Securely stores and manages authentication tokens
- **Automatic Token Refresh** — Handles token expiration and refresh automatically
- **Platform-Specific Login Flows** — Optimized for web, mobile, and desktop platforms
- **Resource-Based Authorization** — Control access to resources based on user permissions
- **Integration with eni_svc** — Seamlessly integrates with the Eniware service architecture
- **Flexible User Model** — Customize user objects to fit your application's needs

---

## Getting Started

To begin using `eni_auth` in your project, install the package via:

```bash
dart pub add eni_auth
```

## Usage

### 1. Create a Custom User Class

Extend the `AuthUser` class to create your custom User model:

```dart
import 'package:eni_auth/eni_auth.dart';

class MyUser extends AuthUser {
  final String id;
  final String name;
  final String email;
  final String accessToken;

  MyUser({required this.id,
    required this.name,
    required this.email,
    required this.accessToken});
}
```

### 2. Set Up the Auth Package

Register the auth package in your app's main function:

```dart
import 'package:eni_auth/eni_auth.dart';
import 'package:eni_auth/oauth2.dart';
import 'package:eni_config/eni_config.dart';
import 'package:eni_svc/eni_svc.dart';
import 'package:eni_utils/logger.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(ServiceScope(
    builder: (context, bootstrapLevel) {
      // Only show the app when services are ready
      if (bootstrapLevel != RunLevel.ready) {
        return const MaterialApp(
          home: Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          ),
        );
      }

      return MaterialApp(
        title: 'ENI Auth Example',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: const AuthDemoScreen(title: 'ENI Auth Example'),
      );
    },
  )
    ..addAppConfig()
    ..provide<ConfigProvider>(MemoryConfigProvider(config: config))
    ..provide<Package>(
      _AuthPackageProvider(
        controller: authController,
        autoConfigure: true,
      ),
    ));
}
```

### 3. Configure OAuth2 Settings

Add OAuth2 configuration to your app's configuration:

```dart
  final config = {
  'auth': {
    'provider': 'oauth2',
    'authorizationEndpoint': 'https://accounts.google.com/o/oauth2/v2/auth',
    'tokenEndpoint': 'https://oauth2.googleapis.com/token',
    'clientId': '<YOUR_CLIENT_ID>',
    'clientSecret': '<YOUT_CLIENT_SECRET>',
    'scopes': ['openid', 'profile', 'email'],
    'platform': {
      //overwrites default values from default_config.dart (mostly not necessary):
      //'web': {'redirect_url': '/login/oidc/callback'},
      //'io':  {'redirect_url': 'http://localhost:9004/login/oidc/callback'}
    }
  }
};
```

### 4. Use the AuthBuilder Widget

Use the `AuthBuilder` widget to conditionally render UI based on authentication state:

```dart
class AuthDemoScreen extends StatefulWidget {
  const AuthDemoScreen({super.key, required this.title});

  final String title;

  @override
  State<AuthDemoScreen> createState() => _AuthDemoScreenState();
}

class _AuthDemoScreenState extends State<AuthDemoScreen> {
  bool _isLoading = false;

  // Create a logger instance for this class
  final Logger _logger = loggerFor('AuthDemoScreen');

  /// Handle the login button press.
  ///
  /// This method calls the login method on the AuthService and
  /// shows a loading indicator while the login is in progress.
  Future<void> _handleLogin(BuildContext context) async {
    // Store a reference to the ScaffoldMessengerState before the async gap
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await context.auth.login();
      if (!success) {
        _logger.w('Login failed');
        if (mounted) {
          // Use the stored reference instead of accessing through context
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Login failed')),
          );
        }
      }
    } catch (e) {
      _logger.e('Error during login: $e');
      if (mounted) {
        // Use the stored reference instead of accessing through context
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Handle the logout button press.
  ///
  /// This method calls the logout method on the AuthService.
  Future<void> _handleLogout(BuildContext context) async {
    await context.auth.logout();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : AuthBuilder<MyUser>(
          builder: (context, user) {
            if (user == null) {
              // User is not authenticated
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'You are not logged in',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => _handleLogin(context),
                    child: const Text('Login'),
                  ),
                ],
              );
            } else {
              // User is authenticated
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'You are logged in as:',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    user.name,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    user.email,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => _handleLogout(context),
                    child: const Text('Logout'),
                  ),
                ],
              );
            }
          },
        ),
      ),
    );
  }
}
```

### 5. Handle Login and Logout

Access the auth service from any widget using the BuildContext extension:

```dart
class AuthDemoScreen extends StatefulWidget {
  const AuthDemoScreen({super.key, required this.title});

  final String title;

  @override
  State<AuthDemoScreen> createState() => _AuthDemoScreenState();
}

class _AuthDemoScreenState extends State<AuthDemoScreen> {
  bool _isLoading = false;

  // Create a logger instance for this class
  final Logger _logger = loggerFor('AuthDemoScreen');

  /// Handle the login button press.
  ///
  /// This method calls the login method on the AuthService and
  /// shows a loading indicator while the login is in progress.
  Future<void> _handleLogin(BuildContext context) async {
    // Store a reference to the ScaffoldMessengerState before the async gap
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await context.auth.login();
      if (!success) {
        _logger.w('Login failed');
        if (mounted) {
          // Use the stored reference instead of accessing through context
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Login failed')),
          );
        }
      }
    } catch (e) {
      _logger.e('Error during login: $e');
      if (mounted) {
        // Use the stored reference instead of accessing through context
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Handle the logout button press.
  ///
  /// This method calls the logout method on the AuthService.
  Future<void> _handleLogout(BuildContext context) async {
    await context.auth.logout();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : AuthBuilder<MyUser>(
          builder: (context, user) {
            if (user == null) {
              // User is not authenticated
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'You are not logged in',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => _handleLogin(context),
                    child: const Text('Login'),
                  ),
                ],
              );
            } else {
              // User is authenticated
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'You are logged in as:',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    user.name,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    user.email,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => _handleLogout(context),
                    child: const Text('Logout'),
                  ),
                ],
              );
            }
          },
        ),
      ),
    );
  }
}
```

### 6. Use AuthController for further processing
Define an `AuthController` to handle user creation, login, logout, and resource access control:  
```dart
final authController = () {
  final logger = loggerFor('AuthController');

  return AuthController<MyUser, BuildContext>(
    onCreateUser: MyUser.fromOAuth2,
    onLogin: (user) {
      logger.i('User logged in: $user');
    },
    onLogout: (user) {
      logger.i('User logged out: $user');
    },
    onGrantResource: (user, resource) {
      // Custom resource access control
      return true;
    },
  );
}();
```

## Architecture

The following classes form the foundation for authentication and authorization processes in this package:

### 1. **AuthService**  
_AuthService<TUser, TResource, TLoginFlowListener> (auth_service.dart)_
- Manages authentication, AuthProvider, and AuthController
- Provides methods for login, logout, and resource verification
- Initializes via a ServiceRegistry mechanism

### 2. **AuthController**  
_AuthController<TUser, TResource> (auth_provider.dart)_
- Holds callbacks for user creation, login, logout, and resource granting
- Enables flexible customization of authentication behavior

### 3. **AuthProvider (abstract)**  
_AuthProvider<TUser, TResource, TLoginFlowListener> (auth_provider.dart)_
- Defines interfaces for authentication providers
- Manages the current user, login/logout, and resource verification
- Extended by concrete implementations like OAuth2Provider

### 4. **OAuth2Provider**  
_OAuth2Provider<TUser, TResource> (oauth2_provider.dart)_
- Implements AuthProvider for OAuth2/OIDC
- Manages the complete OAuth2 login flow, token management, and user status
- Uses a CredentialsStore for secure storage of credentials
- Provides methods for login, logout, token refresh, and status queries

### 5. **AuthUser**  
_AuthUser (auth_user.dart)_
- Abstract base class for user objects

### 6. **AuthenticationError**  
_AuthenticationError (oauth2_provider.dart)_
- Error class for authentication problems

### 7. **OAuth2LoginFlowListener**    
_OAuth2LoginFlowListener (oauth2_provider.dart)_
- Listener class for OAuth2 login events

### 8. **OAuth2CredentialsStore / OAuth2SecureCredentialsStore**  
_oauth2_credentials_store.dart_
- Interface and implementation for secure storage of OAuth2 credentials

## License

This project is licensed under the MIT License.

Copyright © 2025 Eniware Systems GmbH

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
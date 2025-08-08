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

  MyUser({required this.id, required this.name, required this.email});
}
```

### 2. Set Up the Auth Package

Register the auth package in your app's main function:

```dart
import 'package:eni_auth/eni_auth.dart';
import 'package:eni_svc/eni_svc.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(
    ServiceScope(child: const MyApp())
      ..addAuth<MyUser, String>(
        controller: AuthController<MyUser, String>(
          onCreateUser: (params) => MyUser(
            id: params['sub'] ?? '',
            name: params['name'] ?? '',
            email: params['email'] ?? '',
          ),
          onLogin: (user) => print('User logged in: ${user.name}'),
          onLogout: (user) => print('User logged out: ${user.name}'),
          onGrantResource: (user, resource) => true, // Custom authorization logic
        ),
      ),
  );
}
```

### 3. Configure OAuth2 Settings

Add OAuth2 configuration to your app's configuration:

```dart
final config = {
  "auth": {
    "provider": "oauth2",
    "authorizationEndpoint": "https://your-auth-server.com/authorize",
    "tokenEndpoint": "https://your-auth-server.com/token",
    "clientId": "your-client-id",
    "clientSecret": "your-client-secret", // Optional
    "platform": {
      "web": {"redirect_url": "/login/oidc/callback"},
      "io": {"redirect_url": "http://localhost:9004/login/oidc/callback"}
    }
  }
};
```

### 4. Use the AuthBuilder Widget

Use the `AuthBuilder` widget to conditionally render UI based on authentication state:

```dart
import 'package:eni_auth/eni_auth.dart';
import 'package:flutter/material.dart';

class MyHomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('My App')),
      body: Center(
        child: AuthBuilder<MyUser>(
          builder: (context, user) {
            if (user == null) {
              return ElevatedButton(
                onPressed: () => context.auth.login(),
                child: Text('Login'),
              );
            } else {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Welcome, ${user.name}!'),
                  ElevatedButton(
                    onPressed: () => context.auth.logout(),
                    child: Text('Logout'),
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
import 'package:eni_auth/eni_auth.dart';
import 'package:flutter/material.dart';

class LoginLogoutExample extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Trigger login
        ElevatedButton(
          onPressed: () async {
            final success = await context.auth.login();
            if (success) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Login successful')),
              );
            }
          },
          child: Text('Login'),
        ),
        
        // Trigger logout
        ElevatedButton(
          onPressed: () async {
            await context.auth.logout();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Logged out')),
            );
          },
          child: Text('Logout'),
        ),
      ],
    );
  }
}
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
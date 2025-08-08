import 'package:eni_auth/eni_auth.dart';
import 'package:eni_auth/oauth2.dart';
import 'package:eni_config/eni_config.dart';
import 'package:eni_svc/eni_svc.dart';
import 'package:eni_utils/logger.dart';
import 'package:flutter/material.dart';

/// This example demonstrates how to use the eni_auth package to implement
/// OAuth2 authentication in a Flutter application.
///
/// The example shows:
/// - How to create a custom user class that extends AuthUser
/// - How to configure the eni_auth package with OAuth2 authentication
/// - How to implement a simple login/logout flow
/// - How to use the AuthBuilder widget to build UI based on authentication state

void main() {
  // Initialize the application
  runApp(const MyApp());
}

/// A custom user class that extends AuthUser.
///
/// This class represents a user in your application and can include
/// any user-specific properties and methods.
class MyUser extends AuthUser {
  final String id;
  final String name;
  final String email;

  MyUser({
    required this.id,
    required this.name,
    required this.email,
  });

  /// Factory method to create a MyUser from OAuth2 parameters.
  ///
  /// This method is called by the OAuth2Provider when a user is authenticated.
  /// The params map contains the user information from the OAuth2 provider.
  factory MyUser.fromOAuth2(Map<String, dynamic> params) {
    return MyUser(
      id: params['sub'] ?? '',
      name: params['name'] ?? '',
      email: params['email'] ?? '',
    );
  }

  @override
  String toString() => 'MyUser(id: $id, name: $name, email: $email)';
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Create a logger instance for this class
  final Logger _logger = loggerFor('MyApp');

  @override
  Widget build(BuildContext context) {
    // Configure the application with OAuth2 settings
    final config = {
      'auth': {
        'provider': 'dummy', // Using DummyAuthProvider for simplicity
        'authorizationEndpoint':
            'https://your-auth-server.com/oauth2/authorize',
        'tokenEndpoint': 'https://your-auth-server.com/oauth2/token',
        'clientId': 'your-client-id',
        'clientSecret': 'your-client-secret',
        'scopes': ['openid', 'profile', 'email'],
        'platform': {
          'web': {'redirect_url': '/login/oidc/callback'},
          'io': {'redirect_url': 'http://localhost:9004/login/oidc/callback'}
        }
      }
    };

    // Create an auth controller that knows how to create MyUser objects
    final authController = AuthController<MyUser, BuildContext>(
      onCreateUser: MyUser.fromOAuth2,
      onLogin: (user) {
        _logger.i('User logged in: $user');
      },
      onLogout: (user) {
        _logger.i('User logged out: $user');
      },
      onGrantResource: (user, resource) {
        // You can implement custom resource access control here
        return true; // Allow access to all resources
      },
    );

    return ServiceScope(
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
          home: const MyHomePage(title: 'ENI Auth Example'),
        );
      },
    )
      ..provide<ConfigProvider>(MemoryConfigProvider(config: config))
      ..provide<Package>(
        _AuthPackageProvider(
          controller: authController,
          autoConfigure: true,
        ),
      );
  }
}

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

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _isLoading = false;

  // Create a logger instance for this class
  final Logger _logger = loggerFor('MyHomePage');

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

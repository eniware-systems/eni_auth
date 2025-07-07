import 'dart:async';
import 'dart:io';

import 'package:async/async.dart';
import 'package:eni_auth/oauth2.dart';
import 'package:eni_utils/logger.dart';
import 'package:flutter/services.dart';
import 'package:oauth2/oauth2.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

import 'default_config.dart';

const _configParamRedirectUrl = "auth.platform.io.redirect_url";

CancelableOperation<Client?> loginFlow({
  required Map<String, dynamic> config,
  required Logger logger,
  required AuthorizationCodeGrant grant,
  required List<String> scopes,
  OAuth2LoginFlowListener? listener,
}) {
  final cancellation = StreamController<Client?>();

  return CancelableOperation.fromFuture(Future(() async {
    await windowManager.ensureInitialized();

    late final Uri redirectUrl;
    if (config.containsKey(_configParamRedirectUrl)) {
      redirectUrl = Uri.parse(config[_configParamRedirectUrl].toString());
    } else {
      redirectUrl = Uri.parse(defaultRedirectUrlIo);
    }

    logger.d("Local OAuth2 redirect URL is $redirectUrl");

    final server = await HttpServer.bind(redirectUrl.host, redirectUrl.port);

    final authorizationUrl =
        grant.getAuthorizationUrl(redirectUrl, scopes: scopes);
    logger.d("Opening authorization URL");

    await WindowManager.instance.minimize();

    try {
      final canLaunch = await canLaunchUrl(authorizationUrl);

      if (canLaunch) {
        await launchUrl(authorizationUrl);
      }

      await listener?.onOpenAuthorization?.call(authorizationUrl);
    } catch (e) {
      logger.e("Could not open login page: ${e.toString()}");
      return null;
    }

    late final Map<String, String> params;

    final client = await Future.any([
      cancellation.stream.first,
      Future<Client?>(() async {
        final request = await server.firstWhere((request) {
          final requestUri = request.requestedUri;

          if (requestUri.isScheme(redirectUrl.scheme) &&
              requestUri.host == redirectUrl.host &&
              requestUri.port == redirectUrl.port &&
              requestUri.userInfo == redirectUrl.userInfo &&
              requestUri.path == redirectUrl.path) {
            return true;
          }

          request.response.statusCode = 404;
          request.response.close();
          logger.w("Invalid OAuth2 login response received $requestUri");
          return false;
        });

        request.response.statusCode = 200;
        request.response.headers.set('content-type', 'text/html');
        final responseBody =
            await rootBundle.loadString("packages/eni_auth/callback.html");
        request.response.writeln(responseBody);
        await request.response.flush();
        // TODO: This seems to shutdown the connection too fast because the browser will see a refused connection for some reason
        await request.response.close();
        params = request.uri.queryParameters;
        logger.d("Received OAuth2 login response");

        await WindowManager.instance.show();
        await WindowManager.instance.focus();

        return await grant.handleAuthorizationResponse(params);
      })
    ]);

    await server.close();
    return client;
  }), onCancel: () => cancellation.add(null));
}

Future loginInit({required Map<String, dynamic> config}) {
  return Future.value();
}

import 'dart:async';

import 'package:async/async.dart';
import 'package:eni_auth/oauth2.dart';
import 'package:eni_auth/src/oauth2/default_config.dart';
import 'package:eni_utils/logger.dart';
import 'package:oauth2/oauth2.dart';
import 'package:universal_html/html.dart' as html;
import 'package:url_launcher/url_launcher.dart';

const _redirectRealPath = "/assets/packages/eni_auth/callback.html";

Future<Map<String, String>> _awaitAuthenticationResponse() {
  // This is a tricky one. So what we do here is redirecting to the
  // authorization URL but before that we are registering a window message
  // listener to receive the query parameters forwarded from callback.html.
  final responseStreamController = StreamController<Map<String, String>>();

  // Support for BroadcastChannel (for communication between browser tabs)
  html.BroadcastChannel("eni-auth").onMessage.listen((event) {
    final data = event.data.toString();

    final responseUri = Uri.parse(data);
    responseStreamController.add(responseUri.queryParameters);
  });

  // Support for window.opener as a fallback (when BroadcastChannel is not supported)
  html.window.onMessage.listen((event) {
    try {
      const prefix = "eni-auth=";
      final data = event.data.toString();
      if (!data.startsWith(prefix)) {
        return;
      }
      final responseUri = Uri.parse(data.substring(prefix.length));
      responseStreamController.add(responseUri.queryParameters);
    } catch (_) {
      // Ignore
    }
  });

  return responseStreamController.stream.first;
}

const _configParamRedirectUrl = "auth.platform.web.redirect_url";

Uri _getRedirectUrl(Map<String, dynamic> config) {
  late Uri redirectUrl;
  if (config.containsKey(_configParamRedirectUrl)) {
    redirectUrl = Uri.parse(config[_configParamRedirectUrl].toString());
  } else {
    redirectUrl = Uri.parse(defaultRedirectUrlWeb);
  }

  if (!redirectUrl.isAbsolute) {
    redirectUrl = Uri.base.resolveUri(redirectUrl);
  }

  return redirectUrl;
}

CancelableOperation<Client?> loginFlow({
  required Map<String, dynamic> config,
  required Logger logger,
  required AuthorizationCodeGrant grant,
  required List<String> scopes,
  OAuth2LoginFlowListener? listener,
}) {
  final cancellation = StreamController<Client?>();

  return CancelableOperation.fromFuture(Future(() async {
    /// Redirect to callback.html which is being provided by this package.
    var redirectUrl = _getRedirectUrl(config);

    final authorizationUrl =
        grant.getAuthorizationUrl(redirectUrl, scopes: scopes);

    final client = await Future.any([
      cancellation.stream.first,
      Future<Client?>(() async {
        final responseFuture = _awaitAuthenticationResponse();

        logger.d("Opening authorization URL $redirectUrl, scopes:=$scopes");
        try {
          final canLaunch = await canLaunchUrl(authorizationUrl);

          if (canLaunch) {
            await launchUrl(authorizationUrl, webOnlyWindowName: "_blank");
          }

          await listener?.onOpenAuthorization?.call(authorizationUrl);
        } catch (e) {
          logger.e("Could not open login page: ${e.toString()}");
          return null;
        }

        logger.d("Awaiting authorization response...");
        final responseQueryParams = await responseFuture;

        return await grant.handleAuthorizationResponse(responseQueryParams);
      })
    ]);
    return client;
  }), onCancel: () => cancellation.add(null));
}

Future loginInit({required Map<String, dynamic> config}) async {
  var redirectUrl = _getRedirectUrl(config);

  if (Uri.base.host == redirectUrl.host &&
      Uri.base.port == redirectUrl.port &&
      Uri.base.path == redirectUrl.path) {
    redirectUrl = Uri.base.replace(path: _redirectRealPath);

    html.window.location.href = redirectUrl.toString();

    // Block loading basically forever
    await Future.delayed(const Duration(days: 1));
  }
}

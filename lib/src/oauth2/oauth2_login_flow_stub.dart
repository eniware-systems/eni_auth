import 'package:async/async.dart';
import 'package:eni_auth/oauth2.dart';
import 'package:eni_utils/logger.dart';
import 'package:oauth2/oauth2.dart';

CancelableOperation<Client?> loginFlow({
  required Map<String, dynamic> config,
  required Logger logger,
  required AuthorizationCodeGrant grant,
  required List<String> scopes,
  OAuth2LoginFlowListener? listener,
}) {
  logger.w("Platform is not supported");

  final credentials = Credentials("");
  return CancelableOperation.fromValue(Client(credentials));
}

Future loginInit({required Map<String, dynamic> config}) {
  return Future.value();
}

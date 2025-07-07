import 'package:eni_auth/src/oauth2/default_config.dart';
import 'package:eni_config/eni_config.dart';
import 'package:eni_svc/eni_svc.dart';

final _config = {
  "auth": {
    "platform": {
      "io": {"redirect_url": defaultRedirectUrlIo},
      "web": {"redirect_url": defaultRedirectUrlWeb}
    }
  }
};

final defaultPackageConfiguration = Configuration(_config,
    serviceNamePattern: "eni_auth", serviceType: Package);

final defaultConfigProvider = MemoryConfigProvider(config: _config);

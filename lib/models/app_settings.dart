enum AadeEnvironment {
  development('https://mydataapidev.aade.gr'),
  production('https://mydatapi.aade.gr/myDATA');

  const AadeEnvironment(this.baseUrl);

  final String baseUrl;

  bool get isProduction => this == AadeEnvironment.production;

  static AadeEnvironment fromStorage(String? value) {
    return value == AadeEnvironment.production.name
        ? AadeEnvironment.production
        : AadeEnvironment.development;
  }
}

class AppSettings {
  const AppSettings({
    this.username = '',
    this.afm = '',
    this.subscriptionKey = '',
    this.environment = AadeEnvironment.development,
  });

  final String username;
  final String afm;
  final String subscriptionKey;
  final AadeEnvironment environment;

  AppSettings copyWith({
    String? username,
    String? afm,
    String? subscriptionKey,
    AadeEnvironment? environment,
  }) {
    return AppSettings(
      username: username ?? this.username,
      afm: afm ?? this.afm,
      subscriptionKey: subscriptionKey ?? this.subscriptionKey,
      environment: environment ?? this.environment,
    );
  }
}

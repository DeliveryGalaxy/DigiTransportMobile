class AppSettings {
  const AppSettings({
    this.username = '',
    this.afm = '',
    this.subscriptionKey = '',
  });

  final String username;
  final String afm;
  final String subscriptionKey;

  AppSettings copyWith({
    String? username,
    String? afm,
    String? subscriptionKey,
  }) {
    return AppSettings(
      username: username ?? this.username,
      afm: afm ?? this.afm,
      subscriptionKey: subscriptionKey ?? this.subscriptionKey,
    );
  }
}

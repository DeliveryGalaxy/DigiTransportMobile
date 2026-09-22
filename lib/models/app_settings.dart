enum ApiEnvironment {
  development('https://i-deliver3.gr/digitransport/api/dev'),
  production('https://i-deliver3.gr/digitransport/api/prod');

  const ApiEnvironment(this.baseUrl);

  final String baseUrl;

  bool get isProduction => this == ApiEnvironment.production;

  static ApiEnvironment fromStorage(String? value) {
    return value == ApiEnvironment.production.name
        ? ApiEnvironment.production
        : ApiEnvironment.development;
  }
}

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
    this.apiEnvironment = ApiEnvironment.development,
    this.token = '',
    this.companyId = 0,
    this.companyConfirmed = false,
    this.companyName = '',
    this.companyAfm = '',
    this.firstName = '',
    this.lastName = '',
    this.identityUserId = '',
    this.pin = '',
    this.isMetaforiki = false,
    this.isContainer = false,
    this.isOther = false,
    this.isMetaforeas = true,
  });

  final String username;
  final String afm;
  final String subscriptionKey;
  final AadeEnvironment environment;
  final ApiEnvironment apiEnvironment;
  final String token;
  final int companyId;
  final bool companyConfirmed;
  final String companyName;
  final String companyAfm;
  final String firstName;
  final String lastName;
  final String identityUserId;
  final String pin;
  final bool isMetaforiki;
  final bool isContainer;
  final bool isOther;
  final bool isMetaforeas;

  bool get shouldDisplayPlated => isMetaforiki || isContainer;

  bool get isLoggedIn => token.trim().isNotEmpty;

  bool get isReady =>
      companyConfirmed &&
      companyId > 0 &&
      firstName.trim().isNotEmpty &&
      lastName.trim().isNotEmpty &&
      identityUserId.trim().isNotEmpty &&
      isLoggedIn;

  AppSettings copyWith({
    String? username,
    String? afm,
    String? subscriptionKey,
    AadeEnvironment? environment,
    ApiEnvironment? apiEnvironment,
    String? token,
    int? companyId,
    bool? companyConfirmed,
    String? companyName,
    String? companyAfm,
    String? firstName,
    String? lastName,
    String? identityUserId,
    String? pin,
    bool? isMetaforiki,
    bool? isContainer,
    bool? isOther,
    bool? isMetaforeas,
  }) {
    return AppSettings(
      username: username ?? this.username,
      afm: afm ?? this.afm,
      subscriptionKey: subscriptionKey ?? this.subscriptionKey,
      environment: environment ?? this.environment,
      apiEnvironment: apiEnvironment ?? this.apiEnvironment,
      token: token ?? this.token,
      companyId: companyId ?? this.companyId,
      companyConfirmed: companyConfirmed ?? this.companyConfirmed,
      companyName: companyName ?? this.companyName,
      companyAfm: companyAfm ?? this.companyAfm,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      identityUserId: identityUserId ?? this.identityUserId,
      pin: pin ?? this.pin,
      isMetaforiki: isMetaforiki ?? this.isMetaforiki,
      isContainer: isContainer ?? this.isContainer,
      isOther: isOther ?? this.isOther,
      isMetaforeas: isMetaforeas ?? this.isMetaforeas,
    );
  }
}

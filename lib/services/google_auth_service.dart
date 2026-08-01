import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

final googleAuthService = GoogleAuthService();

class GoogleAuthService {
  static const clientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  static const gmailMetadataScopes = <String>[
    'https://www.googleapis.com/auth/gmail.metadata',
  ];

  final userNotifier = ValueNotifier<GoogleSignInAccount?>(null);
  final errorNotifier = ValueNotifier<String?>(null);

  bool _initialized = false;

  bool get isConfigured => clientId.isNotEmpty;

  Future<void> initialize() async {
    if (!isConfigured || _initialized) return;

    final signIn = GoogleSignIn.instance;
    await signIn.initialize(clientId: clientId);
    signIn.authenticationEvents.listen(
      (event) {
        userNotifier.value = switch (event) {
          GoogleSignInAuthenticationEventSignIn() => event.user,
          GoogleSignInAuthenticationEventSignOut() => null,
        };
        errorNotifier.value = null;
      },
      onError: (Object error) {
        userNotifier.value = null;
        if (error is GoogleSignInException &&
            error.code == GoogleSignInExceptionCode.canceled) {
          errorNotifier.value = null;
          return;
        }
        errorNotifier.value = error.toString();
      },
    );
    _initialized = true;
    await signIn.attemptLightweightAuthentication();
  }

  bool get supportsInteractiveAuthentication =>
      GoogleSignIn.instance.supportsAuthenticate();

  Future<void> authenticate() async {
    try {
      await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (error) {
      if (error.code != GoogleSignInExceptionCode.canceled) {
        errorNotifier.value = error.description ?? error.code.name;
      }
    }
  }

  Future<void> disconnect() async {
    await GoogleSignIn.instance.disconnect();
    userNotifier.value = null;
  }

  /// Ends only the current local Google session so another account can be
  /// selected. Already scanned YDI results remain stored locally.
  Future<void> switchAccount() async {
    await GoogleSignIn.instance.signOut();
    userNotifier.value = null;
    errorNotifier.value = null;
  }

  Future<Map<String, String>> authorizeGmailMetadata(
    GoogleSignInAccount user,
  ) async {
    final existingAuthorization = await user.authorizationClient
        .authorizationForScopes(gmailMetadataScopes);
    if (existingAuthorization == null) {
      await user.authorizationClient.authorizeScopes(gmailMetadataScopes);
    }
    final headers = await user.authorizationClient.authorizationHeaders(
      gmailMetadataScopes,
    );
    if (headers == null) {
      throw StateError('Google hat keine Gmail-Autorisierung zurückgegeben.');
    }
    return headers;
  }
}

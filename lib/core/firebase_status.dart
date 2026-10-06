/// Why Firebase setup failed at startup (see main.dart), or null if it
/// succeeded. Kept so screens that need Firebase can show the real reason
/// instead of a generic "not signed in".
Object? firebaseStartupError;

/// A human-readable hint for the most common setup mistakes.
String describeFirebaseStartupError(Object error) {
  final message = error.toString();
  if (message.contains('No Firebase App') ||
      message.contains('not-initialized') ||
      message.contains('FirebaseOptions')) {
    return 'Firebase isn\'t configured in this build: google-services.json '
        'was missing when the app was built. Check the GOOGLE_SERVICES_JSON '
        'variable in Codemagic.';
  }
  if (message.contains('admin-restricted-operation') ||
      message.contains('operation-not-allowed')) {
    return 'Anonymous sign-in is turned off. Enable it in the Firebase '
        'console under Authentication → Sign-in method → Anonymous.';
  }
  if (message.contains('network-request-failed')) {
    return 'Couldn\'t reach Firebase. Check your internet connection and '
        'restart the app.';
  }
  return message;
}

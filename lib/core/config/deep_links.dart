/// Custom URL scheme the password-reset email link opens back into the app.
///
/// Still needs, outside of this Dart code:
///  - Native registration: an intent-filter in AndroidManifest.xml and a
///    CFBundleURLTypes entry in ios/Runner/Info.plist for this scheme.
///  - Adding this exact URL to Supabase Dashboard -> Authentication ->
///    URL Configuration -> Redirect URLs, or resetPasswordForEmail's
///    redirectTo will be rejected.
class AppDeepLinks {
  AppDeepLinks._();

  static const resetPassword = 'io.localease.softadv://reset-password';
}

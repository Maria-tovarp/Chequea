import 'user_session.dart';

class LoginResult {
  const LoginResult._({this.session, this.errorMessage, this.brandingName});
  const LoginResult.success(UserSession session) : this._(session: session);
  const LoginResult.failure(String message) : this._(errorMessage: message);
  const LoginResult.brandingBlocked(String brandingName)
    : this._(brandingName: brandingName);
  final UserSession? session;
  final String? errorMessage;
  final String? brandingName;
  bool get isSuccess => session != null;
  bool get isBrandingBlocked => brandingName != null;
}

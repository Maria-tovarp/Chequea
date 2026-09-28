class UserSession {
  const UserSession({
    required this.username,
    required this.country,
    required this.isChequeandomeAgent,
    required this.refreshToken,
    required this.accessToken,
    this.fullName,
    this.inviteLink,
  });
  final String username;
  final String country;
  final bool isChequeandomeAgent;
  final String refreshToken;
  final String accessToken;
  final String? fullName;
  final String? inviteLink;
}

class UserSession {
  const UserSession({
    required this.username,
    required this.country,
    required this.isChequeandomeAgent,
    required this.refreshToken,
    required this.accessToken,
    this.fullName,
    this.email,
    this.cellphone,
    this.inviteLink,
    this.doctorPhotoPath,
    this.specialty,
    this.specialtyTitle,
    this.bankAccountNumber,
    this.bankAccountType,
    this.bankName,
    this.bankAccountHolder,
  });
  final String username;
  final String country;
  final bool isChequeandomeAgent;
  final String refreshToken;
  final String accessToken;
  final String? fullName;
  final String? email;
  final String? cellphone;
  final String? inviteLink;
  final String? doctorPhotoPath;
  final String? specialty;
  final String? specialtyTitle;
  final String? bankAccountNumber;
  final String? bankAccountType;
  final String? bankName;
  final String? bankAccountHolder;
}

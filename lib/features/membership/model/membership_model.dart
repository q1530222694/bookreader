/// MembershipStatus holds the current VIP status for the user.
class MembershipStatus {
  final bool isVip;
  final String level;
  final String? expiryDate;

  const MembershipStatus({
    required this.isVip,
    required this.level,
    required this.expiryDate,
  });
}

/// MembershipConfig holds server-driven membership feature configuration.
class MembershipConfig {
  final bool enableVip;
  final String vipDescription;

  const MembershipConfig({
    required this.enableVip,
    required this.vipDescription,
  });
}

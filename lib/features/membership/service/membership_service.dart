import 'dart:async';

import '../model/membership_model.dart';

/// MembershipService simulates membership backend operations.
///
/// In a production app, this layer should call real network APIs.
class MembershipService {
  /// Fetch membership status for the current user.
  Future<MembershipStatus> fetchMembershipStatus() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return const MembershipStatus(
      isVip: false,
      level: 'free',
      expiryDate: null,
    );
  }

  /// Simulate a local membership configuration fetch.
  Future<MembershipConfig> fetchMembershipConfig() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return const MembershipConfig(enableVip: true, vipDescription: '云端配置支持');
  }
}

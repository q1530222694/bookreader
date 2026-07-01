import '../../../engine/permission_engine.dart';
import '../model/membership_model.dart';
import '../service/membership_service.dart';

/// MembershipController coordinates membership checks and exposes
/// permission-aware operations for membership-related UI.
class MembershipController {
  MembershipController._();

  static void initialize() {
    // Feature-specific initialization can be placed here.
  }

  /// Returns true when membership features are enabled by server permission.
  static bool isMembershipEnabled() {
    return PermissionEngine.hasPermission('membership.enable');
  }

  /// Get the current membership status from the service layer.
  static Future<MembershipStatus> fetchMembershipStatus() {
    return MembershipService().fetchMembershipStatus();
  }
}

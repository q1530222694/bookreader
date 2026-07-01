import 'controller/membership_controller.dart';

/// Membership feature registration entry.
class MembershipRegister {
  static void register() {
    MembershipController.initialize();
  }
}

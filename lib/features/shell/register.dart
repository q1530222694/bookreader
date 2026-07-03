import '../image_to_pdf/register.dart';
import '../membership/register.dart';
import '../payment/register.dart';

class ShellRegister {
  static void register() {
    // Shell feature registration entry point.
    MembershipRegister.register();
    PaymentRegister.register();
    ImageToPdfRegister.register();
  }
}

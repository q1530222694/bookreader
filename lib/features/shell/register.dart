import '../image_to_pdf/register.dart';
import '../membership/register.dart';
import '../payment/register.dart';
import '../txt_to_epub/register.dart';
import '../doc_to_pdf/register.dart';
import '../ppt_to_pdf/register.dart';
import '../excel_to_pdf/register.dart';

class ShellRegister {
  static void register() {
    // Shell feature registration entry point.
    MembershipRegister.register();
    PaymentRegister.register();
    ImageToPdfRegister.register();
    TxtToEpubRegister.register();
    DocToPdfRegister.register();
    PptToPdfRegister.register();
    ExcelToPdfRegister.register();
  }
}

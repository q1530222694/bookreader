import 'package:flutter/foundation.dart';

class ShellController {
  final ValueNotifier<int> selectedIndex = ValueNotifier<int>(0);

  void setIndex(int index) {
    selectedIndex.value = index;
  }

  void dispose() {
    selectedIndex.dispose();
  }
}

import 'package:flutter/foundation.dart';

import 'settings_controller.dart';
import '../../../engine/settings_engine.dart';

class ShellController {
  int _initialIndexFromStartup() {
    try {
      final page = SettingsController.startupPage.value;
      switch (page) {
        case SettingsEngine.startupPageBookshelf:
          return 1;
        case SettingsEngine.startupPageMemory:
          return 2;
        case SettingsEngine.startupPageTools:
          return 3;
        case SettingsEngine.startupPageProfile:
          return 4;
        case SettingsEngine.startupPageHome:
        case SettingsEngine.startupPageNone:
        default:
          return 0;
      }
    } catch (_) {
      return 0;
    }
  }

  final ValueNotifier<int> selectedIndex = ValueNotifier<int>(0);

  ShellController() {
    selectedIndex.value = _initialIndexFromStartup();
  }

  void setIndex(int index) {
    selectedIndex.value = index;
  }

  void dispose() {
    selectedIndex.dispose();
  }
}

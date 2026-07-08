import 'package:flutter/cupertino.dart';

import '../../../engine/localization_engine.dart';

/// SettingsPage provides the global settings entry surface.
///
/// Language and appearance options are intentionally hidden here because they are
/// already exposed in the outer settings area of the app.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final backgroundColor = CupertinoColors.systemBackground.resolveFrom(context);
    return CupertinoPageScaffold(
      backgroundColor: backgroundColor,
      navigationBar: CupertinoNavigationBar(
        middle: Text(LocalizationEngine.text('settings')),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: const [],
        ),
      ),
    );
  }
}

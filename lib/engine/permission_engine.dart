import 'dart:convert';

import 'config.dart';

/// PermissionEngine fetches server-driven permissions and exposes
/// verification APIs for features that require membership or access control.
class PermissionEngine {
  PermissionEngine._();

  static const _configKey = 'engine.permissions';

  /// Initialize permission state from server-driven JSON payload.
  ///
  /// The returned JSON payload should contain a map of feature keys to bool.
  /// Example: {"membership.enable": true, "payment.enable": true}
  static void initializeFromJson(String rawJson) {
    final decoded = jsonDecode(rawJson);
    if (decoded is Map<String, dynamic>) {
      for (final entry in decoded.entries) {
        Config.set('$_configKey.${entry.key}', entry.value);
      }
    }
  }

  /// Check whether the current permission configuration allows [featureKey].
  ///
  /// This method is the only allowed access check for permission gated features.
  static bool hasPermission(String featureKey) {
    final value = Config.get('$_configKey.$featureKey');
    return value == true;
  }

  /// Save raw permission payload for debugging or later inspection.
  static void cacheRawPayload(String rawJson) {
    Config.set('$_configKey.raw', rawJson);
  }
}

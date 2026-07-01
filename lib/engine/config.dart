/// Global configuration helper used by the app to store and observe state.
///
/// This class is intentionally simple and designed for cross-module
/// communication through explicit keys only.
class Config {
  Config._();

  static final Map<String, Object?> _store = {};
  static final Map<String, List<void Function(Object?)>> _listeners = {};

  /// Set a configuration value for the given [key].
  /// This is the only supported cross-module state mutation interface.
  static void set(String key, Object? value) {
    _store[key] = value;
    if (_listeners.containsKey(key)) {
      for (final callback in List<void Function(Object?)>.from(
        _listeners[key]!,
      )) {
        callback(value);
      }
    }
  }

  /// Get a previously stored configuration value by [key].
  /// Returns null when the value has not been set.
  static Object? get(String key) {
    return _store[key];
  }

  /// Register a listener for changes to a specific [key].
  /// The listener is invoked whenever that key is updated.
  static void watch(String key, void Function(Object?) callback) {
    _listeners.putIfAbsent(key, () => []).add(callback);
  }

  /// Remove a previously registered listener from the [key].
  static void unwatch(String key, void Function(Object?) callback) {
    final listeners = _listeners[key];
    if (listeners == null) return;
    listeners.remove(callback);
    if (listeners.isEmpty) {
      _listeners.remove(key);
    }
  }
}

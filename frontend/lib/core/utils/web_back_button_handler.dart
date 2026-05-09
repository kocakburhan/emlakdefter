import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';

/// Handles browser back button prevention on web platform
/// Emits an event when user tries to navigate back via browser
class WebBackButtonHandler {
  static bool _isInitialized = false;
  static final StreamController<void> _backButtonStream = StreamController<void>.broadcast();

  /// Stream that emits when browser back button is pressed
  static Stream<void> get onBackButtonPressed => _backButtonStream.stream;

  /// Initialize browser history management
  /// Call this once at app startup
  static void initialize() {
    if (_isInitialized) return;

    // Only run on web
    if (kIsWeb) {
      // Prevent accidental browser back navigation by adding a fake state
      // This effectively neutralizes the browser back button
      html.window.history.pushState(null, '', html.window.location.href);

      // Listen for popstate events (browser back button)
      html.window.onPopState.listen((html.Event event) {
        // Push state to keep user on current page
        html.window.history.pushState(null, '', html.window.location.href);
        // Emit event for listeners
        _backButtonStream.add(null);
      });
    }

    _isInitialized = true;
  }

  /// Dispose the stream controller
  static void dispose() {
    _backButtonStream.close();
  }
}

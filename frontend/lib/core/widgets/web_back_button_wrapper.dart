import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../utils/web_back_button_handler.dart';

/// A widget that wraps the app and intercepts browser back button on web
/// Shows a confirmation dialog instead of navigating back
class WebBackButtonWrapper extends StatefulWidget {
  final Widget child;

  const WebBackButtonWrapper({
    super.key,
    required this.child,
  });

  @override
  State<WebBackButtonWrapper> createState() => _WebBackButtonWrapperState();
}

class _WebBackButtonWrapperState extends State<WebBackButtonWrapper> {
  @override
  void initState() {
    super.initState();
    // Initialize browser history management on web
    if (kIsWeb) {
      WebBackButtonHandler.initialize();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Mixin to add web back button handling to any screen
/// Usage: extend ConsumerState<MyScreen> with WebBackButtonMixin
mixin WebBackButtonMixin<T extends StatefulWidget> on State<T> {
  Future<bool> handleWebBackButton() async {
    // On mobile, always allow back
    if (!kIsWeb) return true;

    // On web, show the dialog
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.web, color: Colors.white70, size: 22),
            SizedBox(width: 10),
            Text(
              'Geri Dönmek İstiyor musunuz?',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          'Tarayıcınızın geri butonunu kullanmak yerine, ekranın sol üstündeki geri butonunu kullanın.',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Tamam',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );

    return result ?? false;
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/colors.dart';

/// Reusable back button widget that properly handles navigation.
/// Uses go_router's pop instead of Navigator.pop for proper web browser history support.
class AppBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String? routeToNavigate;

  const AppBackButton({
    super.key,
    this.onPressed,
    this.routeToNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (onPressed != null) {
          onPressed!();
        } else if (routeToNavigate != null) {
          context.go(routeToNavigate!);
        } else {
          // Default behavior: try to pop the current route
          context.pop();
        }
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: const Icon(
          Icons.arrow_back_rounded,
          color: AppColors.charcoal,
          size: 20,
        ),
      ),
    );
  }
}

/// Alternative: A more prominent back button with text
class AppBackButtonWithText extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;

  const AppBackButtonWithText({
    super.key,
    this.text = 'Geri',
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (onPressed != null) {
          onPressed!();
        } else {
          context.pop();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.charcoal,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              text,
              style: const TextStyle(
                color: AppColors.charcoal,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

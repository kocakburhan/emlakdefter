import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/colors.dart';

/// Minimalist Loading Indicator Widget
/// Rive veya fallback animasyonlu yükleniyor göstergesi
class LoadingIndicator extends StatelessWidget {
  final String? message;
  final double size;
  final Color? color;

  const LoadingIndicator({
    super.key,
    this.message,
    this.size = 40,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDots(),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDots() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: size / 4,
          height: size / 4,
          decoration: BoxDecoration(
            color: color ?? AppColors.charcoal,
            shape: BoxShape.circle,
          ),
        )
            .animate(
              onPlay: (controller) => controller.repeat(),
            )
            .fadeIn(
              delay: Duration(milliseconds: 200 * index),
              duration: const Duration(milliseconds: 300),
            )
            .then()
            .fadeOut(
              delay: Duration(milliseconds: 200 * index + 300),
              duration: const Duration(milliseconds: 300),
            )
            .scale(
              begin: const Offset(0.5, 0.5),
              end: const Offset(1.0, 1.0),
              delay: Duration(milliseconds: 200 * index),
              duration: const Duration(milliseconds: 300),
            )
            .then()
            .scale(
              begin: const Offset(1.0, 1.0),
              end: const Offset(0.5, 0.5),
              delay: Duration(milliseconds: 200 * index + 300),
              duration: const Duration(milliseconds: 300),
            );
      }),
    );
  }
}

/// Full Screen Loading Overlay
class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? message;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: AppColors.background.withValues(alpha: 0.8),
            child: LoadingIndicator(message: message),
          ),
      ],
    );
  }
}

/// Button Loading State
class ButtonLoadingIndicator extends StatelessWidget {
  final double size;

  const ButtonLoadingIndicator({
    super.key,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: AppColors.textOnPrimary,
      ),
    );
  }
}

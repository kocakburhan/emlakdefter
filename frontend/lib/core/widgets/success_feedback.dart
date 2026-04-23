import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/colors.dart';

/// Success Feedback Widget
/// Animasyonlu başarı gösterimi (checkmark + fade/scale)
class SuccessFeedback extends StatefulWidget {
  final String? message;
  final VoidCallback? onComplete;
  final Duration duration;

  const SuccessFeedback({
    super.key,
    this.message,
    this.onComplete,
    this.duration = const Duration(milliseconds: 2000),
  });

  @override
  State<SuccessFeedback> createState() => _SuccessFeedbackState();
}

class _SuccessFeedbackState extends State<SuccessFeedback> {
  @override
  void initState() {
    super.initState();
    Future.delayed(widget.duration, () {
      widget.onComplete?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated Success Icon
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check,
              color: Colors.white,
              size: 48,
            ),
          )
              .animate()
              .scale(
                begin: const Offset(0.0, 0.0),
                end: const Offset(1.0, 1.0),
                duration: const Duration(milliseconds: 400),
                curve: Curves.elasticOut,
              )
              .fadeIn(duration: const Duration(milliseconds: 200)),

          const SizedBox(height: 24),

          // Message
          if (widget.message != null)
            Text(
              widget.message!,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.textPrimary,
                  ),
              textAlign: TextAlign.center,
            )
                .animate()
                .fadeIn(
                  delay: const Duration(milliseconds: 200),
                  duration: const Duration(milliseconds: 400),
                )
                .slideY(
                  begin: 0.2,
                  end: 0,
                  delay: const Duration(milliseconds: 200),
                  duration: const Duration(milliseconds: 400),
                ),
        ],
      ),
    );
  }
}

/// Success Dialog with animated checkmark
class SuccessDialog extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? buttonText;

  const SuccessDialog({
    super.key,
    required this.title,
    this.subtitle,
    this.buttonText,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated success icon
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: AppColors.successLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: AppColors.success,
                size: 48,
              ),
            )
                .animate()
                .scale(
                  begin: const Offset(0.0, 0.0),
                  end: const Offset(1.0, 1.0),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.elasticOut,
                )
                .fadeIn(duration: const Duration(milliseconds: 200)),

            const SizedBox(height: 24),

            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            )
                .animate()
                .fadeIn(
                  delay: const Duration(milliseconds: 200),
                  duration: const Duration(milliseconds: 400),
                ),

            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              )
                  .animate()
                  .fadeIn(
                    delay: const Duration(milliseconds: 300),
                    duration: const Duration(milliseconds: 400),
                  ),
            ],

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(buttonText ?? 'Tamam'),
              ),
            )
                .animate()
                .fadeIn(
                  delay: const Duration(milliseconds: 400),
                  duration: const Duration(milliseconds: 400),
                )
                .slideY(
                  begin: 0.2,
                  end: 0,
                  delay: const Duration(milliseconds: 400),
                  duration: const Duration(milliseconds: 400),
                ),
          ],
        ),
      ),
    );
  }
}

/// Error Feedback Widget with animated X icon
class ErrorFeedback extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorFeedback({
    super.key,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated error icon
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: AppColors.errorLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline,
              color: AppColors.error,
              size: 48,
            ),
          )
              .animate()
              .scale(
                begin: const Offset(0.0, 0.0),
                end: const Offset(1.0, 1.0),
                duration: const Duration(milliseconds: 400),
                curve: Curves.elasticOut,
              )
              .fadeIn(duration: const Duration(milliseconds: 200)),

          const SizedBox(height: 24),

          Text(
            message,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.error,
                ),
            textAlign: TextAlign.center,
          )
              .animate()
              .fadeIn(
                delay: const Duration(milliseconds: 200),
                duration: const Duration(milliseconds: 400),
              ),

          if (onRetry != null) ...[
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tekrar Dene'),
            )
                .animate()
                .fadeIn(
                  delay: const Duration(milliseconds: 400),
                  duration: const Duration(milliseconds: 400),
                ),
          ],
        ],
      ),
    );
  }
}

/// Animated Success Checkmark - standalone widget
class AnimatedCheckmark extends StatelessWidget {
  final double size;
  final Color? color;
  final Duration duration;

  const AnimatedCheckmark({
    super.key,
    this.size = 48,
    this.color,
    this.duration = const Duration(milliseconds: 600),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: (color ?? AppColors.success).withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.check_rounded,
        color: color ?? AppColors.success,
        size: size * 0.6,
      ),
    )
        .animate()
        .scale(
          begin: const Offset(0.5, 0.5),
          end: const Offset(1.0, 1.0),
          duration: duration,
          curve: Curves.elasticOut,
        )
        .fadeIn(duration: 200.ms);
  }
}

/// Animated Error X - standalone widget
class AnimatedErrorX extends StatelessWidget {
  final double size;
  final Color? color;
  final Duration duration;

  const AnimatedErrorX({
    super.key,
    this.size = 48,
    this.color,
    this.duration = const Duration(milliseconds: 600),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: (color ?? AppColors.error).withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.close_rounded,
        color: color ?? AppColors.error,
        size: size * 0.6,
      ),
    )
        .animate()
        .scale(
          begin: const Offset(0.5, 0.5),
          end: const Offset(1.0, 1.0),
          duration: duration,
          curve: Curves.elasticOut,
        )
        .fadeIn(duration: 200.ms);
  }
}

/// Pulse Animation Widget - for notifications/important items
class PulseWidget extends StatefulWidget {
  final Widget child;
  final bool isActive;
  final Duration duration;

  const PulseWidget({
    super.key,
    required this.child,
    this.isActive = true,
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  State<PulseWidget> createState() => _PulseWidgetState();
}

class _PulseWidgetState extends State<PulseWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    if (widget.isActive) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(PulseWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isActive && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 + (_controller.value * 0.05),
          child: Opacity(
            opacity: 1.0 - (_controller.value * 0.2),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/colors.dart';

/// Empty State Widget
/// Minimalist illüstrasyon ile boş durum gösterimi
class EmptyState extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? buttonText;
  final VoidCallback? onButtonPressed;
  final IconData? icon;

  const EmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.buttonText,
    this.onButtonPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon with animation
            if (icon != null)
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 48,
                  color: AppColors.slateGray,
                ),
              )
                  .animate()
                  .scale(
                    begin: const Offset(0.8, 0.8),
                    end: const Offset(1.0, 1.0),
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOut,
                  )
                  .fadeIn(duration: const Duration(milliseconds: 400)),

            if (icon == null)
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.inbox_outlined,
                  size: 48,
                  color: AppColors.slateGray,
                ),
              )
                  .animate()
                  .scale(
                    begin: const Offset(0.8, 0.8),
                    end: const Offset(1.0, 1.0),
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOut,
                  )
                  .fadeIn(duration: const Duration(milliseconds: 400)),

            const SizedBox(height: 24),

            // Title
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
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
                  curve: Curves.easeOut,
                ),

            // Subtitle
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                textAlign: TextAlign.center,
              )
                  .animate()
                  .fadeIn(
                    delay: const Duration(milliseconds: 300),
                    duration: const Duration(milliseconds: 400),
                  )
                  .slideY(
                    begin: 0.2,
                    end: 0,
                    delay: const Duration(milliseconds: 300),
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOut,
                  ),
            ],

            // Button
            if (buttonText != null && onButtonPressed != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onButtonPressed,
                child: Text(buttonText!),
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
                    curve: Curves.easeOut,
                  ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Minimalist Empty List Placeholder
class EmptyListPlaceholder extends StatelessWidget {
  final String message;

  const EmptyListPlaceholder({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: AppColors.lightGray,
          )
              .animate()
              .fadeIn(duration: const Duration(milliseconds: 400))
              .scale(
                begin: const Offset(0.5, 0.5),
                end: const Offset(1.0, 1.0),
                duration: const Duration(milliseconds: 400),
              ),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textTertiary,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Animated Empty State with custom illustration widget
class AnimatedEmptyState extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? illustration;
  final String? buttonText;
  final VoidCallback? onButtonPressed;

  const AnimatedEmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.illustration,
    this.buttonText,
    this.onButtonPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Custom illustration or default icon
            if (illustration != null)
              illustration!
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1), duration: 400.ms)
            else
              Icon(
                Icons.folder_open_outlined,
                size: 80,
                color: AppColors.slateGray,
              )
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1), duration: 400.ms),

            const SizedBox(height: 24),

            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.textPrimary,
                  ),
              textAlign: TextAlign.center,
            )
                .animate()
                .fadeIn(delay: 200.ms, duration: 400.ms)
                .slideY(begin: 0.2, end: 0, delay: 200.ms, duration: 400.ms, curve: Curves.easeOut),

            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                textAlign: TextAlign.center,
              )
                  .animate()
                  .fadeIn(delay: 300.ms, duration: 400.ms)
                  .slideY(begin: 0.2, end: 0, delay: 300.ms, duration: 400.ms, curve: Curves.easeOut),
            ],

            if (buttonText != null && onButtonPressed != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onButtonPressed,
                child: Text(buttonText!),
              )
                  .animate()
                  .fadeIn(delay: 400.ms, duration: 400.ms)
                  .slideY(begin: 0.2, end: 0, delay: 400.ms, duration: 400.ms, curve: Curves.easeOut),
            ],
          ],
        ),
      ),
    );
  }
}
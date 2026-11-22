import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import 'mcmap_logo.dart';

/// Shared McGill-styled layout for the sign-in screens: off-white page, a
/// thin McGill-red band on top, and a centred white card with an icon in a
/// red-tint circle, a serif title and a short subtitle.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    this.icon,
    required this.title,
    required this.children,
    this.subtitle,
    this.onBack,
    this.backLabel = 'Back',
  });

  /// Status icon in a red-tint circle (setup, errors). Null shows the
  /// McMap logo.
  final IconData? icon;
  final String title;
  final String? subtitle;
  final List<Widget> children;

  /// Shows a small back link at the top of the card.
  final VoidCallback? onBack;
  final String backLabel;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final onBack = this.onBack;

    return Scaffold(
      backgroundColor: McMapColors.background,
      body: Column(
        children: [
          Container(height: 6, color: McMapColors.red),
          Expanded(
            child: SafeArea(
              top: false,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (onBack != null)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: onBack,
                                  icon: const Icon(Icons.arrow_back_rounded),
                                  label: Text(backLabel),
                                ),
                              )
                            else
                              const SizedBox(height: 8),
                            const SizedBox(height: 8),
                            Center(
                              child: switch (icon) {
                                final icon? => Container(
                                  width: 72,
                                  height: 72,
                                  decoration: const BoxDecoration(
                                    color: McMapColors.redTint,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    icon,
                                    size: 36,
                                    color: McMapColors.redStrong,
                                  ),
                                ),
                                null => const McMapLogo(size: 80),
                              },
                            ),
                            const SizedBox(height: 20),
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: text.headlineMedium,
                            ),
                            if (subtitle case final subtitle?) ...[
                              const SizedBox(height: 8),
                              Text(
                                subtitle,
                                textAlign: TextAlign.center,
                                style: text.bodyLarge?.copyWith(
                                  color: McMapColors.slate,
                                ),
                              ),
                            ],
                            const SizedBox(height: 28),
                            ...children,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Spinner sized for a button icon.
class ButtonSpinner extends StatelessWidget {
  const ButtonSpinner({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 18,
    height: 18,
    child: CircularProgressIndicator(strokeWidth: 2, color: McMapColors.white),
  );
}

/// Error line under a form, in burgundy (AA on white).
class AuthError extends StatelessWidget {
  const AuthError(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      message,
      textAlign: TextAlign.center,
      style: const TextStyle(color: McMapColors.burgundy),
    ),
  );
}

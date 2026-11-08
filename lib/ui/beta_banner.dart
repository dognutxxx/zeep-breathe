import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../l10n/strings.dart';

/// "Zeep beta version" strip at the top of the screen. Dismissing it hides it
/// until the app is restarted.
class BetaBanner extends StatelessWidget {
  final AppController app;
  const BetaBanner({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    if (!app.bannerVisible) return const SizedBox.shrink();
    final s = S.of(context);
    const fg = Color(0xFF8A5A00);
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFF1D2),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
          child: Row(
            children: [
              const Icon(Icons.error_outline_rounded, size: 20, color: Color(0xFFD79A1E)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  s.betaBanner,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: fg),
                ),
              ),
              IconButton(
                tooltip: s.close,
                onPressed: app.hideBanner,
                icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFFD79A1E)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

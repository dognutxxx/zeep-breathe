import 'package:flutter/material.dart';

import 'zeep_colors.dart';

/// Blue integer slider styled like the prototype (blue fill, white knob).
class ZeepSlider extends StatelessWidget {
  final int value, min, max;
  final ValueChanged<int> onChanged;
  final ValueChanged<int>? onChangeEnd;
  final String semanticLabel;

  const ZeepSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.onChangeEnd,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 7,
        activeTrackColor: ZeepColors.blue,
        inactiveTrackColor: ZeepColors.track,
        thumbColor: Colors.white,
        overlayColor: withAlpha(ZeepColors.blue, 0.08),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 11, elevation: 2, pressedElevation: 4),
        tickMarkShape: SliderTickMarkShape.noTickMark,
        showValueIndicator: ShowValueIndicator.never,
        trackShape: const RoundedRectSliderTrackShape(),
      ),
      child: Slider(
        value: value.toDouble(),
        min: min.toDouble(),
        max: max.toDouble(),
        divisions: max - min,
        semanticFormatterCallback: (v) => '$semanticLabel ${v.round()}',
        onChanged: (v) => onChanged(v.round()),
        onChangeEnd: onChangeEnd == null ? null : (v) => onChangeEnd!(v.round()),
      ),
    );
  }
}

/// Text link with a leading icon (e.g. "breathing settings", "How it works").
class LinkButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const LinkButton({super.key, required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      style: TextButton.styleFrom(foregroundColor: ZeepColors.blue),
    );
  }
}

/// Rounded-square playback control.
class ControlButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback onTap;
  final String tooltip;
  const ControlButton({super.key, required this.icon, required this.onTap, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Material(
          color: ZeepColors.btnBg,
          elevation: 2,
          shadowColor: withAlpha(Colors.black, 0.25),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: SizedBox(width: 56, height: 56, child: Center(child: icon)),
          ),
        ),
      ),
    );
  }
}

/// Icon with a diagonal "off" slash.
class SlashedIcon extends StatelessWidget {
  final IconData icon;
  final bool on;
  final Color color;
  const SlashedIcon({super.key, required this.icon, required this.on, required this.color});

  @override
  Widget build(BuildContext context) {
    return Stack(alignment: Alignment.center, children: [
      Icon(icon, color: color, size: 24),
      if (!on)
        Transform.rotate(
          angle: 0.785,
          child: Container(
            width: 2.2,
            height: 28,
            decoration: BoxDecoration(
              color: color,
              border: Border.symmetric(vertical: BorderSide(color: ZeepColors.btnBg, width: 1.5)),
            ),
          ),
        ),
    ]);
  }
}

/// Soft background gradient used behind every screen.
class ZeepBackground extends StatelessWidget {
  final Widget child;
  const ZeepBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [ZeepColors.bgTop, ZeepColors.bgBottom],
        ),
      ),
      child: child,
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/nebula_theme.dart';

/// Stylised glowing "N" mark used for the logo and the center of the ring.
class NebulaMark extends StatelessWidget {
  final double size;
  const NebulaMark({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _NebulaMarkPainter()),
    );
  }
}

class _NebulaMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rect = Offset.zero & size;
    final shader = NebulaGradients.glow.createShader(rect);

    // Stylised N: left riser, diagonal, right riser with a slight swirl tail.
    final path = Path()
      ..moveTo(w * 0.18, h * 0.82)
      ..lineTo(w * 0.18, h * 0.18)
      ..lineTo(w * 0.80, h * 0.82)
      ..lineTo(w * 0.80, h * 0.18);

    final glow = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.14
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.10);
    canvas.drawPath(path, glow);

    final stroke = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.13
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Cosmic dark backdrop with soft teal nebula glows.
class NebulaBackground extends StatelessWidget {
  final Widget child;
  const NebulaBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: NebulaGradients.background),
      child: Stack(
        children: [
          // Soft glow blobs.
          Positioned(
            top: -80,
            left: -60,
            child: _blob(220, NebulaColors.teal.withOpacity(0.10)),
          ),
          Positioned(
            top: 120,
            right: -90,
            child: _blob(260, NebulaColors.cyan.withOpacity(0.08)),
          ),
          Positioned(
            bottom: -60,
            left: -40,
            child: _blob(200, NebulaColors.blue.withOpacity(0.06)),
          ),
          child,
        ],
      ),
    );
  }

  Widget _blob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color, blurRadius: 120, spreadRadius: 60)],
      ),
    );
  }
}

/// The big glowing connect ring with a shield + N mark and a status label.
class NebulaConnectRing extends StatelessWidget {
  final double size;
  final bool connected;
  final bool connecting;
  final String statusLabel;
  final Widget timer;
  final VoidCallback onTap;

  const NebulaConnectRing({
    super.key,
    required this.size,
    required this.connected,
    required this.connecting,
    required this.statusLabel,
    required this.timer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ringColor = connected
        ? NebulaColors.teal
        : connecting
            ? NebulaColors.orange
            : NebulaColors.textFaint;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: _RingPainter(active: connected || connecting,
                  color: ringColor),
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(Icons.shield_outlined,
                        size: size * 0.40,
                        color: ringColor.withOpacity(0.45)),
                    NebulaMark(size: size * 0.20),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: size * 0.06),
          Text(statusLabel.toUpperCase(),
              style: NebulaText.status.copyWith(color: ringColor)),
          const SizedBox(height: 6),
          timer,
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final bool active;
  final Color color;
  _RingPainter({required this.active, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 10;

    // Faint full track.
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..color = NebulaColors.border.withOpacity(0.6);
    canvas.drawCircle(center, radius, track);

    // Glowing arc (≈320°).
    final rect = Rect.fromCircle(center: center, radius: radius);
    final sweepShader = SweepGradient(
      startAngle: 0,
      endAngle: 2 * math.pi,
      colors: const [
        NebulaColors.green,
        NebulaColors.teal,
        NebulaColors.cyan,
        NebulaColors.green,
      ],
    ).createShader(rect);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = active ? 8 : 5
      ..strokeCap = StrokeCap.round
      ..shader = active ? sweepShader : null
      ..color = active ? Colors.white : NebulaColors.textFaint.withOpacity(0.5);

    if (active) {
      final glow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..shader = sweepShader
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
      canvas.drawArc(rect, -math.pi / 2 + 0.4, math.pi * 1.78, false, glow);
    }

    canvas.drawArc(rect, -math.pi / 2 + 0.4, math.pi * 1.78, false, arc);

    // Inner soft disc.
    final disc = Paint()
      ..shader = RadialGradient(colors: [
        color.withOpacity(0.10),
        Colors.transparent,
      ]).createShader(Rect.fromCircle(center: center, radius: radius * 0.8));
    canvas.drawCircle(center, radius * 0.8, disc);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.active != active || oldDelegate.color != color;
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

const _gradientStart = Color(0xFF7C8CF8);
const _gradientEnd = Color(0xFF4A55C9);
const _glow = Color(0xFF5F5FD4);

class ScissorsLogo extends StatefulWidget {
  final double size;
  final bool animate;

  const ScissorsLogo({super.key, this.size = 96, this.animate = true});

  @override
  State<ScissorsLogo> createState() => _ScissorsLogoState();
}

class _ScissorsLogoState extends State<ScissorsLogo>
    with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();
  late final Animation<double> _scale = CurvedAnimation(
    parent: _intro,
    curve: Curves.elasticOut,
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0, 0.6, curve: Curves.easeOut),
  );

  AnimationController? _snip;
  Animation<double>? _angle;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      final snip = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1600),
      )..repeat();
      _angle = TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween(begin: 0.30, end: 0.05)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 16,
        ),
        TweenSequenceItem(
          tween: Tween(begin: 0.05, end: 0.30)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 16,
        ),
        TweenSequenceItem(
          tween: Tween(begin: 0.30, end: 0.05)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 16,
        ),
        TweenSequenceItem(
          tween: Tween(begin: 0.05, end: 0.30)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 16,
        ),
        TweenSequenceItem(tween: ConstantTween(0.30), weight: 36),
      ]).animate(snip);
      _snip = snip;
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _snip?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;

    final badge = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [_gradientStart, _gradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
          width: math.max(1, size * 0.02),
        ),
        boxShadow: [
          BoxShadow(
            color: _glow.withValues(alpha: 0.38),
            blurRadius: size * 0.28,
            offset: Offset(0, size * 0.10),
          ),
        ],
      ),
      child: Center(
        child: _angle == null
            ? CustomPaint(
                size: Size.square(size * 0.62),
                painter: _ScissorsPainter(
                  halfAngle: 0.30,
                  color: Colors.white,
                  accent: _gradientEnd,
                ),
              )
            : AnimatedBuilder(
                animation: _angle!,
                builder: (context, _) => CustomPaint(
                  size: Size.square(size * 0.62),
                  painter: _ScissorsPainter(
                    halfAngle: _angle!.value,
                    color: Colors.white,
                    accent: _gradientEnd,
                  ),
                ),
              ),
      ),
    );

    return AnimatedBuilder(
      animation: _intro,
      builder: (context, child) => Opacity(
        opacity: _fade.value,
        child: Transform.scale(scale: _scale.value, child: child),
      ),
      child: badge,
    );
  }
}

class _ScissorsPainter extends CustomPainter {
  final double halfAngle;
  final Color color;
  final Color accent;

  _ScissorsPainter({
    required this.halfAngle,
    required this.color,
    required this.accent,
  });

  // Fixed spread angle (radians) for the handles/rings. This is
  // intentionally NOT tied to the animated blade `halfAngle`: the rings sit
  // fairly close to the pivot, so if they opened/closed with the same small
  // angle as the blades they'd overlap at low angles. Keeping the handle
  // spread constant (and wide enough) guarantees the two rings never touch,
  // no matter what the blades are doing.
  static const double _handleSpread = 0.34;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    final center = Offset(size.width / 2, size.height / 2);
    final pivot = Offset(50 * s, 55 * s);

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.5 * s
      ..strokeCap = StrokeCap.round;

    // Lay the whole icon out horizontally (blades pointing sideways,
    // handles/rings on the opposite side) instead of the original
    // vertical orientation.
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(math.pi / 2);
    canvas.translate(-center.dx, -center.dy);

    void drawHalf(int dir) {
      // Blade: animates with the snip angle.
      canvas.save();
      canvas.translate(pivot.dx, pivot.dy);
      canvas.rotate(halfAngle * dir);
      final blade = Path()
        ..moveTo(0, 2 * s)
        ..quadraticBezierTo(-6 * s, -13 * s, -1.8 * s, -34 * s)
        ..quadraticBezierTo(0, -38 * s, 1.8 * s, -34 * s)
        ..quadraticBezierTo(6 * s, -13 * s, 0, 2 * s)
        ..close();
      canvas.drawPath(blade, fill);
      canvas.restore();

      // Handle + ring: fixed spread so the rings stay clear of each other.
      canvas.save();
      canvas.translate(pivot.dx, pivot.dy);
      canvas.rotate(_handleSpread * dir);
      canvas.drawLine(Offset(0, 2 * s), Offset(0, 12 * s), stroke);
      canvas.drawCircle(Offset(0, 25 * s), 7.5 * s, stroke);
      canvas.restore();
    }

    drawHalf(1);
    drawHalf(-1);

    canvas.drawCircle(pivot, 4.6 * s, Paint()..color = color);
    canvas.drawCircle(pivot, 2 * s, Paint()..color = accent);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_ScissorsPainter oldDelegate) =>
      oldDelegate.halfAngle != halfAngle ||
      oldDelegate.color != color ||
      oldDelegate.accent != accent;
}

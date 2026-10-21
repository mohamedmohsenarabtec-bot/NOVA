import 'package:flutter/material.dart';

/// Original NOVA mark: two joined paths form an N, with a connection spark.
/// Geometry is also the source for native icons and SVG exports.
class NovaMark extends CustomPainter {
  final Color ink;
  final Color accent;
  const NovaMark({required this.ink, required this.accent});

  static const leftPath =
      'M 24 76 V 34 Q 24 24 34 30 L 66 70 Q 76 80 76 66 V 38';
  static const rightPath = 'M 76 76 V 66 M 24 34 V 24';
  static const sparkPath =
      'M 76 8 L 80 20 L 92 24 L 80 28 L 76 40 L 72 28 L 60 24 L 72 20 Z';

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final line = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(24, 76)
        ..lineTo(24, 34)
        ..quadraticBezierTo(24, 24, 34, 30)
        ..lineTo(66, 70)
        ..quadraticBezierTo(76, 80, 76, 66)
        ..lineTo(76, 38),
      line,
    );
    canvas.drawPath(
      Path()
        ..moveTo(76, 76)
        ..lineTo(76, 66)
        ..moveTo(24, 34)
        ..lineTo(24, 24),
      line,
    );
    canvas.drawPath(
      Path()
        ..moveTo(76, 8)
        ..lineTo(80, 20)
        ..lineTo(92, 24)
        ..lineTo(80, 28)
        ..lineTo(76, 40)
        ..lineTo(72, 28)
        ..lineTo(60, 24)
        ..lineTo(72, 20)
        ..close(),
      Paint()..color = accent,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(NovaMark oldDelegate) =>
      ink != oldDelegate.ink || accent != oldDelegate.accent;
}

class NovaLogo extends StatelessWidget {
  final bool symbolOnly;
  final double size;
  const NovaLogo({super.key, this.symbolOnly = false, this.size = 34});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      label: 'NOVA',
      image: true,
      child: ExcludeSemantics(
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomPaint(
                size: Size.square(size),
                painter: NovaMark(
                  ink: dark ? const Color(0xFFC2B5FF) : const Color(0xFF6554C0),
                  accent: dark
                      ? const Color(0xFFFFA18E)
                      : const Color(0xFFB74C40),
                ),
              ),
              if (!symbolOnly &&
                  (size > 34 || MediaQuery.sizeOf(context).width >= 480)) ...[
                const SizedBox(width: 8),
                Text(
                  'NOVA',
                  style: TextStyle(
                    fontSize: size * .62,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

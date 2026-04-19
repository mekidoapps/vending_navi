import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapMarkerFactory {
  static Future<BitmapDescriptor> createMachineMarker({
    required String manufacturer,
    bool selected = false,
    int size = 132,
  }) async {
    final Color baseColor = _manufacturerColor(manufacturer);
    final String label = _manufacturerLabel(manufacturer);

    final int resolvedSize = selected ? size + 12 : size;
    final double s = resolvedSize.toDouble();

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    final Offset center = Offset(s / 2, s * 0.40);

    final double outerRadius = s * 0.21;
    final double innerRadius = s * 0.165;
    final double tailHeight = s * 0.16;
    final double tailWidth = s * 0.13;

    final Paint shadowPaint = Paint()
      ..color = const Color(0x33000000)
      ..maskFilter = MaskFilter.blur(
        BlurStyle.normal,
        selected ? 12 : 9,
      );

    final Paint outerRingPaint = Paint()
      ..color = selected ? const Color(0xFF7C4DFF) : Colors.white
      ..style = PaintingStyle.fill;

    final Paint bodyPaint = Paint()
      ..color = baseColor
      ..style = PaintingStyle.fill;

    final Paint bodyBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = selected ? 5 : 4;

    final Path tailPath = Path()
      ..moveTo(center.dx - tailWidth / 2, center.dy + innerRadius * 0.68)
      ..quadraticBezierTo(
        center.dx,
        center.dy + innerRadius + tailHeight,
        center.dx + tailWidth / 2,
        center.dy + innerRadius * 0.68,
      )
      ..close();

    final Path shadowTailPath = Path.from(tailPath)
      ..shift(const Offset(0, 5));

    // shadow
    canvas.drawCircle(
      center.translate(0, 5),
      outerRadius,
      shadowPaint,
    );
    canvas.drawPath(shadowTailPath, shadowPaint);

    // outer ring + tail
    canvas.drawPath(tailPath, outerRingPaint);
    canvas.drawCircle(center, outerRadius, outerRingPaint);

    // inner body + tail
    final Path innerTailPath = Path()
      ..moveTo(center.dx - tailWidth * 0.36, center.dy + innerRadius * 0.60)
      ..quadraticBezierTo(
        center.dx,
        center.dy + innerRadius + tailHeight * 0.72,
        center.dx + tailWidth * 0.36,
        center.dy + innerRadius * 0.60,
      )
      ..close();

    canvas.drawPath(innerTailPath, bodyPaint);
    canvas.drawCircle(center, innerRadius, bodyPaint);
    canvas.drawCircle(center, innerRadius, bodyBorderPaint);

    // small highlight
    final Paint highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.18)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(center.dx - innerRadius * 0.32, center.dy - innerRadius * 0.30),
      innerRadius * 0.33,
      highlightPaint,
    );

    // text
    final double fontSize;
    if (label.length >= 2) {
      fontSize = s * 0.105;
    } else {
      fontSize = s * 0.155;
    }

    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: label.length >= 2 ? 0.2 : 0,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 1,
    )..layout();

    final Offset textOffset = Offset(
      center.dx - textPainter.width / 2,
      center.dy - textPainter.height / 2,
    );

    textPainter.paint(canvas, textOffset);

    final ui.Image image =
    await recorder.endRecording().toImage(resolvedSize, resolvedSize);
    final ByteData? data =
    await image.toByteData(format: ui.ImageByteFormat.png);

    if (data == null) {
      return BitmapDescriptor.defaultMarker;
    }

    return BitmapDescriptor.fromBytes(
      Uint8List.view(data.buffer),
    );
  }

  static String cacheKey({
    required String manufacturer,
    required bool selected,
  }) {
    return '${manufacturer.trim()}_$selected';
  }

  static Color _manufacturerColor(String manufacturer) {
    switch (manufacturer.trim()) {
      case 'コカ・コーラ':
      case 'コカコーラ':
        return const Color(0xFFE53935);
      case 'サントリー':
        return const Color(0xFF1E88E5);
      case '伊藤園':
        return const Color(0xFF43A047);
      case 'キリン':
        return const Color(0xFFF9A825);
      case 'アサヒ':
        return const Color(0xFFFB8C00);
      case '大塚製薬':
        return const Color(0xFF3949AB);
      case 'AQUO':
        return const Color(0xFF00ACC1);
      case 'ダイドー':
        return const Color(0xFF8E24AA);
      default:
        return const Color(0xFFEC407A);
    }
  }

  static String _manufacturerLabel(String manufacturer) {
    switch (manufacturer.trim()) {
      case 'コカ・コーラ':
      case 'コカコーラ':
        return 'コ';
      case 'サントリー':
        return 'サ';
      case '伊藤園':
        return '伊';
      case 'キリン':
        return 'キ';
      case 'アサヒ':
        return 'ア';
      case '大塚製薬':
        return '大';
      case 'ダイドー':
        return 'ダ';
      case 'AQUO':
        return 'AQ';
      default:
        return '他';
    }
  }
}
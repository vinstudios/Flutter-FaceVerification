import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:flutter/material.dart';


class FacePainterLiveCamera extends CustomPainter {
  final Size imageSize;
  final List<Face> faces;
  FacePainterLiveCamera(this.imageSize, this.faces);

  @override
  void paint(Canvas canvas, Size size) {

    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < faces.length; i++) {
      final rect = _scaleRect( rect: faces[i].boundingBox, imageSize: imageSize, widgetSize: size, );
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(FacePainterLiveCamera oldDelegate) {
    return imageSize != oldDelegate.imageSize || faces != oldDelegate.faces;
  }
}

Rect _scaleRect({
  @required Rect rect,
  @required Size imageSize,
  @required Size widgetSize,
}) {
  final double scaleX = widgetSize.width / imageSize.width;
  final double scaleY = widgetSize.height / imageSize.height;

  return Rect.fromLTRB(
    rect.left.toDouble() * scaleX,
    rect.top.toDouble() * scaleY,
    rect.right.toDouble() * scaleX,
    rect.bottom.toDouble() * scaleY,
  );
}

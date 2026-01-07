import 'dart:math' as math;
import 'dart:ui';

/// Transform matrix utilities for signature manipulation
class TransformUtils {
  /// Create a transformation matrix from translation, rotation, and scale
  static Matrix4 createMatrix({
    required Offset translation,
    required double rotation,
    required double scale,
    Offset? anchor,
  }) {
    final anchorPoint = anchor ?? Offset.zero;
    
    final matrix = Matrix4.identity()
      ..translate(translation.dx, translation.dy)
      ..translate(anchorPoint.dx, anchorPoint.dy)
      ..rotateZ(rotation)
      ..scale(scale)
      ..translate(-anchorPoint.dx, -anchorPoint.dy);
    
    return matrix;
  }

  /// Extract translation from a matrix
  static Offset getTranslation(Matrix4 matrix) {
    return Offset(matrix.entry(0, 3), matrix.entry(1, 3));
  }

  /// Extract rotation (Z-axis) from a matrix in radians
  static double getRotation(Matrix4 matrix) {
    return math.atan2(matrix.entry(1, 0), matrix.entry(0, 0));
  }

  /// Extract uniform scale from a matrix
  static double getScale(Matrix4 matrix) {
    final scaleX = math.sqrt(
      math.pow(matrix.entry(0, 0), 2) + math.pow(matrix.entry(1, 0), 2),
    );
    return scaleX;
  }

  /// Transform a point using a matrix
  static Offset transformPoint(Matrix4 matrix, Offset point) {
    final result = matrix.transform3(
      Vector3(point.dx, point.dy, 0),
    );
    return Offset(result.x, result.y);
  }

  /// Calculate bounding box after transformation
  static Rect transformBounds(Matrix4 matrix, Rect bounds) {
    final corners = [
      transformPoint(matrix, bounds.topLeft),
      transformPoint(matrix, bounds.topRight),
      transformPoint(matrix, bounds.bottomLeft),
      transformPoint(matrix, bounds.bottomRight),
    ];

    double minX = corners[0].dx;
    double maxX = corners[0].dx;
    double minY = corners[0].dy;
    double maxY = corners[0].dy;

    for (final corner in corners) {
      minX = math.min(minX, corner.dx);
      maxX = math.max(maxX, corner.dx);
      minY = math.min(minY, corner.dy);
      maxY = math.max(maxY, corner.dy);
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// Constrain bounds within a container
  static Offset constrainToContainer(
    Rect objectBounds,
    Size containerSize, {
    double margin = 0,
  }) {
    double dx = 0;
    double dy = 0;

    final containerRect = Rect.fromLTWH(
      margin,
      margin,
      containerSize.width - margin * 2,
      containerSize.height - margin * 2,
    );

    if (objectBounds.left < containerRect.left) {
      dx = containerRect.left - objectBounds.left;
    } else if (objectBounds.right > containerRect.right) {
      dx = containerRect.right - objectBounds.right;
    }

    if (objectBounds.top < containerRect.top) {
      dy = containerRect.top - objectBounds.top;
    } else if (objectBounds.bottom > containerRect.bottom) {
      dy = containerRect.bottom - objectBounds.bottom;
    }

    return Offset(dx, dy);
  }

  /// Normalize angle to [-π, π]
  static double normalizeAngle(double angle) {
    while (angle > math.pi) {
      angle -= 2 * math.pi;
    }
    while (angle < -math.pi) {
      angle += 2 * math.pi;
    }
    return angle;
  }

  /// Convert degrees to radians
  static double degreesToRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  /// Convert radians to degrees
  static double radiansToDegrees(double radians) {
    return radians * 180 / math.pi;
  }

  /// Snap angle to nearest increment
  static double snapAngle(double angle, double increment) {
    return (angle / increment).round() * increment;
  }

  /// Calculate distance between two points
  static double distance(Offset p1, Offset p2) {
    return (p2 - p1).distance;
  }

  /// Calculate angle between two points
  static double angleBetween(Offset p1, Offset p2) {
    return math.atan2(p2.dy - p1.dy, p2.dx - p1.dx);
  }
}

/// Extension for Vector3 operations
extension on Matrix4 {
  Vector3 transform3(Vector3 vector) {
    final x = vector.x;
    final y = vector.y;
    final z = vector.z;

    return Vector3(
      entry(0, 0) * x + entry(0, 1) * y + entry(0, 2) * z + entry(0, 3),
      entry(1, 0) * x + entry(1, 1) * y + entry(1, 2) * z + entry(1, 3),
      entry(2, 0) * x + entry(2, 1) * y + entry(2, 2) * z + entry(2, 3),
    );
  }
}

/// Simple 3D vector class
class Vector3 {
  final double x;
  final double y;
  final double z;

  const Vector3(this.x, this.y, this.z);
}

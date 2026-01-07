import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:image/image.dart' as img;

/// Pure Dart implementation of document edge detection and perspective correction
class DocumentScanner {
  /// Detect document edges in an image
  /// Returns list of 4 corner points [topLeft, topRight, bottomRight, bottomLeft]
  static Future<List<Offset>?> detectEdges(Uint8List imageBytes) async {
    final image = img.decodeImage(imageBytes);
    if (image == null) return null;

    // Convert to grayscale
    final grayscale = img.grayscale(image);

    // Apply Gaussian blur
    final blurred = img.gaussianBlur(grayscale, radius: 5);

    // Edge detection using Sobel
    final edges = _applySobel(blurred);

    // Find contours and get the largest quadrilateral
    final corners = _findDocumentCorners(edges, image.width, image.height);

    if (corners == null || corners.length != 4) {
      // Return default corners (full image)
      return [
        const Offset(0, 0),
        Offset(image.width.toDouble(), 0),
        Offset(image.width.toDouble(), image.height.toDouble()),
        Offset(0, image.height.toDouble()),
      ];
    }

    return corners;
  }

  /// Apply Sobel edge detection
  static img.Image _applySobel(img.Image image) {
    final result = img.Image(width: image.width, height: image.height);

    // Sobel kernels
    final sobelX = [
      [-1, 0, 1],
      [-2, 0, 2],
      [-1, 0, 1],
    ];
    final sobelY = [
      [-1, -2, -1],
      [0, 0, 0],
      [1, 2, 1],
    ];

    for (int y = 1; y < image.height - 1; y++) {
      for (int x = 1; x < image.width - 1; x++) {
        double gx = 0;
        double gy = 0;

        for (int ky = -1; ky <= 1; ky++) {
          for (int kx = -1; kx <= 1; kx++) {
            final pixel = image.getPixel(x + kx, y + ky);
            final luminance = img.getLuminance(pixel);
            gx += luminance * sobelX[ky + 1][kx + 1];
            gy += luminance * sobelY[ky + 1][kx + 1];
          }
        }

        final magnitude = math.sqrt(gx * gx + gy * gy).clamp(0, 255).toInt();
        result.setPixelRgba(x, y, magnitude, magnitude, magnitude, 255);
      }
    }

    return result;
  }

  /// Find document corners using contour detection
  static List<Offset>? _findDocumentCorners(
    img.Image edges,
    int width,
    int height,
  ) {
    // Threshold the edges
    final threshold = 50;
    final edgePoints = <Offset>[];

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = edges.getPixel(x, y);
        if (img.getLuminance(pixel) > threshold) {
          edgePoints.add(Offset(x.toDouble(), y.toDouble()));
        }
      }
    }

    if (edgePoints.length < 100) {
      return null;
    }

    // Use convex hull approach to find corners
    final hull = _convexHull(edgePoints);
    if (hull.length < 4) return null;

    // Simplify hull to 4 points
    final corners = _simplifyToQuadrilateral(hull, width, height);
    return _orderCorners(corners);
  }

  /// Compute convex hull using Graham scan
  static List<Offset> _convexHull(List<Offset> points) {
    if (points.length < 3) return points;

    // Find the bottom-most point
    var lowest = points[0];
    for (final p in points) {
      if (p.dy > lowest.dy || (p.dy == lowest.dy && p.dx < lowest.dx)) {
        lowest = p;
      }
    }

    // Sort points by polar angle
    final sorted = List<Offset>.from(points);
    sorted.remove(lowest);
    sorted.sort((a, b) {
      final angleA = math.atan2(a.dy - lowest.dy, a.dx - lowest.dx);
      final angleB = math.atan2(b.dy - lowest.dy, b.dx - lowest.dx);
      return angleA.compareTo(angleB);
    });

    final hull = <Offset>[lowest];

    for (final point in sorted) {
      while (hull.length > 1 &&
          _crossProduct(hull[hull.length - 2], hull.last, point) <= 0) {
        hull.removeLast();
      }
      hull.add(point);
    }

    return hull;
  }

  static double _crossProduct(Offset o, Offset a, Offset b) {
    return (a.dx - o.dx) * (b.dy - o.dy) - (a.dy - o.dy) * (b.dx - o.dx);
  }

  /// Simplify polygon to 4 points
  static List<Offset> _simplifyToQuadrilateral(
    List<Offset> points,
    int width,
    int height,
  ) {
    if (points.length <= 4) return points;

    // Douglas-Peucker simplification
    var simplified = points;
    double epsilon = 10;

    while (simplified.length > 4 && epsilon < 100) {
      simplified = _douglasPeucker(simplified, epsilon);
      epsilon += 10;
    }

    // If still more than 4, take 4 most distant from center
    if (simplified.length > 4) {
      final center = Offset(width / 2, height / 2);
      simplified.sort((a, b) {
        final distA = (a - center).distance;
        final distB = (b - center).distance;
        return distB.compareTo(distA);
      });
      simplified = simplified.take(4).toList();
    }

    return simplified;
  }

  static List<Offset> _douglasPeucker(List<Offset> points, double epsilon) {
    if (points.length < 3) return points;

    double maxDist = 0;
    int index = 0;

    for (int i = 1; i < points.length - 1; i++) {
      final dist = _perpendicularDistance(
        points[i],
        points.first,
        points.last,
      );
      if (dist > maxDist) {
        maxDist = dist;
        index = i;
      }
    }

    if (maxDist > epsilon) {
      final left = _douglasPeucker(points.sublist(0, index + 1), epsilon);
      final right = _douglasPeucker(points.sublist(index), epsilon);
      return [...left.sublist(0, left.length - 1), ...right];
    }

    return [points.first, points.last];
  }

  static double _perpendicularDistance(Offset point, Offset lineStart, Offset lineEnd) {
    final dx = lineEnd.dx - lineStart.dx;
    final dy = lineEnd.dy - lineStart.dy;
    final mag = math.sqrt(dx * dx + dy * dy);
    if (mag == 0) return (point - lineStart).distance;

    final u = ((point.dx - lineStart.dx) * dx + (point.dy - lineStart.dy) * dy) / (mag * mag);
    final closestX = lineStart.dx + u * dx;
    final closestY = lineStart.dy + u * dy;
    return (point - Offset(closestX, closestY)).distance;
  }

  /// Order corners as [topLeft, topRight, bottomRight, bottomLeft]
  static List<Offset> _orderCorners(List<Offset> corners) {
    if (corners.length != 4) return corners;

    // Calculate center
    final center = corners.reduce((a, b) => a + b) / 4.0;

    // Separate into top and bottom pairs
    corners.sort((a, b) => a.dy.compareTo(b.dy));
    final topPair = corners.sublist(0, 2);
    final bottomPair = corners.sublist(2, 4);

    // Sort left to right
    topPair.sort((a, b) => a.dx.compareTo(b.dx));
    bottomPair.sort((a, b) => a.dx.compareTo(b.dx));

    return [
      topPair[0], // topLeft
      topPair[1], // topRight
      bottomPair[1], // bottomRight
      bottomPair[0], // bottomLeft
    ];
  }

  /// Apply perspective transform to crop and straighten document
  static Future<Uint8List?> warpPerspective(
    Uint8List imageBytes,
    List<Offset> corners, {
    int? targetWidth,
    int? targetHeight,
  }) async {
    final image = img.decodeImage(imageBytes);
    if (image == null || corners.length != 4) return null;

    // Calculate output dimensions
    final topWidth = (corners[1] - corners[0]).distance;
    final bottomWidth = (corners[2] - corners[3]).distance;
    final leftHeight = (corners[3] - corners[0]).distance;
    final rightHeight = (corners[2] - corners[1]).distance;

    final outWidth = targetWidth ?? math.max(topWidth, bottomWidth).toInt();
    final outHeight = targetHeight ?? math.max(leftHeight, rightHeight).toInt();

    // Create output image
    final output = img.Image(width: outWidth, height: outHeight);

    // Calculate perspective transform matrix
    final srcPoints = corners;
    final dstPoints = [
      const Offset(0, 0),
      Offset(outWidth.toDouble(), 0),
      Offset(outWidth.toDouble(), outHeight.toDouble()),
      Offset(0, outHeight.toDouble()),
    ];

    final matrix = _getPerspectiveTransform(srcPoints, dstPoints);

    // Apply inverse transform to each output pixel
    for (int y = 0; y < outHeight; y++) {
      for (int x = 0; x < outWidth; x++) {
        final srcPoint = _applyInverseTransform(matrix, x.toDouble(), y.toDouble());

        if (srcPoint.dx >= 0 &&
            srcPoint.dx < image.width &&
            srcPoint.dy >= 0 &&
            srcPoint.dy < image.height) {
          // Bilinear interpolation
          final pixel = _bilinearInterpolation(image, srcPoint.dx, srcPoint.dy);
          output.setPixel(x, y, pixel);
        }
      }
    }

    return Uint8List.fromList(img.encodePng(output));
  }

  /// Get perspective transform matrix (simplified approach)
  static List<double> _getPerspectiveTransform(
    List<Offset> src,
    List<Offset> dst,
  ) {
    // Simplified perspective transform using 8-point algorithm
    final a = <List<double>>[];
    final b = <double>[];

    for (int i = 0; i < 4; i++) {
      a.add([
        src[i].dx,
        src[i].dy,
        1,
        0,
        0,
        0,
        -dst[i].dx * src[i].dx,
        -dst[i].dx * src[i].dy,
      ]);
      b.add(dst[i].dx);
      a.add([
        0,
        0,
        0,
        src[i].dx,
        src[i].dy,
        1,
        -dst[i].dy * src[i].dx,
        -dst[i].dy * src[i].dy,
      ]);
      b.add(dst[i].dy);
    }

    // Solve system using Gaussian elimination
    final h = _solveLinearSystem(a, b);
    return [...h, 1.0];
  }

  static List<double> _solveLinearSystem(List<List<double>> a, List<double> b) {
    final n = b.length;
    final aug = List<List<double>>.generate(
      n,
      (i) => [...a[i], b[i]],
    );

    // Forward elimination
    for (int i = 0; i < n; i++) {
      // Find pivot
      int maxRow = i;
      for (int k = i + 1; k < n; k++) {
        if (aug[k][i].abs() > aug[maxRow][i].abs()) {
          maxRow = k;
        }
      }

      // Swap rows
      final temp = aug[i];
      aug[i] = aug[maxRow];
      aug[maxRow] = temp;

      // Eliminate
      for (int k = i + 1; k < n; k++) {
        if (aug[i][i] == 0) continue;
        final c = aug[k][i] / aug[i][i];
        for (int j = i; j <= n; j++) {
          aug[k][j] -= c * aug[i][j];
        }
      }
    }

    // Back substitution
    final x = List<double>.filled(n, 0);
    for (int i = n - 1; i >= 0; i--) {
      x[i] = aug[i][n];
      for (int j = i + 1; j < n; j++) {
        x[i] -= aug[i][j] * x[j];
      }
      if (aug[i][i] != 0) {
        x[i] /= aug[i][i];
      }
    }

    return x;
  }

  static Offset _applyInverseTransform(List<double> h, double x, double y) {
    // Apply inverse of perspective transform
    final denom = h[6] * x + h[7] * y + h[8];
    if (denom == 0) return Offset(x, y);

    final srcX = (h[0] * x + h[1] * y + h[2]) / denom;
    final srcY = (h[3] * x + h[4] * y + h[5]) / denom;
    return Offset(srcX, srcY);
  }

  static img.Pixel _bilinearInterpolation(img.Image image, double x, double y) {
    final x0 = x.floor();
    final y0 = y.floor();
    final x1 = math.min(x0 + 1, image.width - 1);
    final y1 = math.min(y0 + 1, image.height - 1);

    final fx = x - x0;
    final fy = y - y0;

    final p00 = image.getPixel(x0, y0);
    final p01 = image.getPixel(x0, y1);
    final p10 = image.getPixel(x1, y0);
    final p11 = image.getPixel(x1, y1);

    final r = ((1 - fx) * (1 - fy) * p00.r +
            fx * (1 - fy) * p10.r +
            (1 - fx) * fy * p01.r +
            fx * fy * p11.r)
        .round();
    final g = ((1 - fx) * (1 - fy) * p00.g +
            fx * (1 - fy) * p10.g +
            (1 - fx) * fy * p01.g +
            fx * fy * p11.g)
        .round();
    final b = ((1 - fx) * (1 - fy) * p00.b +
            fx * (1 - fy) * p10.b +
            (1 - fx) * fy * p01.b +
            fx * fy * p11.b)
        .round();
    final a = 255;

    return image.getPixel(0, 0)..setRgba(r, g, b, a);
  }

  /// Enhance document contrast
  static Future<Uint8List?> enhanceContrast(Uint8List imageBytes) async {
    final image = img.decodeImage(imageBytes);
    if (image == null) return null;

    // Apply adaptive thresholding for document enhancement
    final enhanced = img.adjustColor(
      image,
      contrast: 1.3,
      brightness: 1.05,
    );

    return Uint8List.fromList(img.encodePng(enhanced));
  }
}

/// Extension for Offset division
extension OffsetDivision on Offset {
  Offset operator /(double value) => Offset(dx / value, dy / value);
}

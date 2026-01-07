import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import 'package:sign_stamp/core/utils/file_utils.dart';
import 'package:sign_stamp/core/utils/logger.dart';
import 'package:sign_stamp/features/scan/services/document_scanner.dart';

class ScanScreen extends ConsumerStatefulWidget {
  final String imagePath;

  const ScanScreen({super.key, required this.imagePath});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  Uint8List? _imageBytes;
  ui.Image? _uiImage;
  List<Offset>? _corners;
  int? _selectedCorner;
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _errorMessage;
  Size? _imageSize;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final file = File(widget.imagePath);
      final bytes = await file.readAsBytes();

      // Decode image for display
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();

      // Run edge detection in isolate
      final corners = await compute(_detectEdges, bytes);

      setState(() {
        _imageBytes = bytes;
        _uiImage = frame.image;
        _imageSize = Size(
          frame.image.width.toDouble(),
          frame.image.height.toDouble(),
        );
        _corners = corners ?? _getDefaultCorners();
        _isLoading = false;
      });
    } catch (e, stack) {
      AppLogger.error('Failed to load image', e, stack);
      setState(() {
        _errorMessage = 'Failed to load image: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  static Future<List<Offset>?> _detectEdges(Uint8List bytes) async {
    return await DocumentScanner.detectEdges(bytes);
  }

  List<Offset> _getDefaultCorners() {
    if (_imageSize == null) {
      return [
        const Offset(50, 50),
        const Offset(350, 50),
        const Offset(350, 500),
        const Offset(50, 500),
      ];
    }
    final margin = 50.0;
    return [
      Offset(margin, margin),
      Offset(_imageSize!.width - margin, margin),
      Offset(_imageSize!.width - margin, _imageSize!.height - margin),
      Offset(margin, _imageSize!.height - margin),
    ];
  }

  Future<void> _processScan() async {
    if (_imageBytes == null || _corners == null) return;

    setState(() => _isProcessing = true);

    try {
      // Apply perspective transform
      final processedBytes = await compute(
        _warpImage,
        _WarpParams(bytes: _imageBytes!, corners: _corners!),
      );

      if (processedBytes == null) {
        setState(() {
          _errorMessage = 'Failed to process document';
          _isProcessing = false;
        });
        return;
      }

      // Save processed image
      final docDir = await FileUtils.getDocumentsDirectory();
      final fileName = '${const Uuid().v4()}_scanned.png';
      final outputPath = '${docDir.path}/$fileName';
      await File(outputPath).writeAsBytes(processedBytes);

      // Delete original if different
      if (widget.imagePath != outputPath) {
        await FileUtils.deleteFile(widget.imagePath);
      }

      if (mounted) {
        context.pushReplacement('/signatures?selectMode=true&documentPath=$outputPath');
      }
    } catch (e, stack) {
      AppLogger.error('Failed to process scan', e, stack);
      setState(() {
        _errorMessage = 'Failed to process document: ${e.toString()}';
        _isProcessing = false;
      });
    }
  }

  static Future<Uint8List?> _warpImage(_WarpParams params) async {
    return await DocumentScanner.warpPerspective(params.bytes, params.corners);
  }

  void _skipScan() {
    context.pushReplacement(
      '/signatures?selectMode=true&documentPath=${widget.imagePath}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crop Document'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: _isProcessing ? null : _skipScan,
            child: const Text('Skip'),
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _corners != null
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _processScan,
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.crop),
                  label: Text(_isProcessing ? 'Processing...' : 'Apply Crop'),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Detecting document edges...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _errorMessage = null;
                    _isLoading = true;
                  });
                  _loadImage();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_uiImage == null) {
      return const Center(child: Text('No image loaded'));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Drag the corners to adjust the crop area',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return _CropOverlay(
                  image: _uiImage!,
                  corners: _corners!,
                  containerSize: constraints.biggest,
                  selectedCorner: _selectedCorner,
                  onCornerDragStart: (index) {
                    setState(() => _selectedCorner = index);
                  },
                  onCornerDragUpdate: (index, position) {
                    setState(() {
                      _corners![index] = position;
                    });
                  },
                  onCornerDragEnd: () {
                    setState(() => _selectedCorner = null);
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _WarpParams {
  final Uint8List bytes;
  final List<Offset> corners;

  _WarpParams({required this.bytes, required this.corners});
}

class _CropOverlay extends StatelessWidget {
  final ui.Image image;
  final List<Offset> corners;
  final Size containerSize;
  final int? selectedCorner;
  final ValueChanged<int> onCornerDragStart;
  final void Function(int, Offset) onCornerDragUpdate;
  final VoidCallback onCornerDragEnd;

  const _CropOverlay({
    required this.image,
    required this.corners,
    required this.containerSize,
    required this.selectedCorner,
    required this.onCornerDragStart,
    required this.onCornerDragUpdate,
    required this.onCornerDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate scale to fit image in container
    final imageAspect = image.width / image.height;
    final containerAspect = containerSize.width / containerSize.height;

    double scale;
    Offset offset;

    if (imageAspect > containerAspect) {
      scale = containerSize.width / image.width;
      offset = Offset(0, (containerSize.height - image.height * scale) / 2);
    } else {
      scale = containerSize.height / image.height;
      offset = Offset((containerSize.width - image.width * scale) / 2, 0);
    }

    final scaledCorners = corners
        .map((c) => Offset(c.dx * scale + offset.dx, c.dy * scale + offset.dy))
        .toList();

    return Stack(
      children: [
        // Image
        Positioned(
          left: offset.dx,
          top: offset.dy,
          child: RawImage(
            image: image,
            width: image.width * scale,
            height: image.height * scale,
            fit: BoxFit.contain,
          ),
        ),
        // Overlay and crop area
        CustomPaint(
          size: containerSize,
          painter: _CropPainter(
            corners: scaledCorners,
            primaryColor: Theme.of(context).colorScheme.primary,
          ),
        ),
        // Corner handles
        for (int i = 0; i < 4; i++)
          Positioned(
            left: scaledCorners[i].dx - 20,
            top: scaledCorners[i].dy - 20,
            child: GestureDetector(
              onPanStart: (_) => onCornerDragStart(i),
              onPanUpdate: (details) {
                // Convert screen position back to image coordinates
                final newScreenPos = scaledCorners[i] + details.delta;
                final newImagePos = Offset(
                  (newScreenPos.dx - offset.dx) / scale,
                  (newScreenPos.dy - offset.dy) / scale,
                );

                // Clamp to image bounds
                final clampedPos = Offset(
                  newImagePos.dx.clamp(0, image.width.toDouble()),
                  newImagePos.dy.clamp(0, image.height.toDouble()),
                );

                onCornerDragUpdate(i, clampedPos);
              },
              onPanEnd: (_) => onCornerDragEnd(),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: selectedCorner == i
                      ? Theme.of(context).colorScheme.primary
                      : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.drag_indicator,
                  size: 20,
                  color: selectedCorner == i
                      ? Colors.white
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CropPainter extends CustomPainter {
  final List<Offset> corners;
  final Color primaryColor;

  _CropPainter({
    required this.corners,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw semi-transparent overlay
    final overlayPaint = Paint()..color = Colors.black.withOpacity(0.5);
    final cropPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final cropArea = Path()
      ..moveTo(corners[0].dx, corners[0].dy)
      ..lineTo(corners[1].dx, corners[1].dy)
      ..lineTo(corners[2].dx, corners[2].dy)
      ..lineTo(corners[3].dx, corners[3].dy)
      ..close();

    final overlayPath =
        Path.combine(PathOperation.difference, cropPath, cropArea);
    canvas.drawPath(overlayPath, overlayPaint);

    // Draw crop border
    final borderPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawPath(cropArea, borderPaint);

    // Draw edge lines with dashed pattern
    final edgePaint = Paint()
      ..color = primaryColor.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (int i = 0; i < 4; i++) {
      final start = corners[i];
      final end = corners[(i + 1) % 4];
      canvas.drawLine(start, end, edgePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CropPainter oldDelegate) {
    return oldDelegate.corners != corners;
  }
}

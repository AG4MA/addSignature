import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:uuid/uuid.dart';
import 'package:image/image.dart' as img;

import 'package:sign_stamp/core/providers/repositories_provider.dart';
import 'package:sign_stamp/core/utils/file_utils.dart';
import 'package:sign_stamp/core/utils/logger.dart';
import 'package:sign_stamp/features/signature/data/models/signature_model.dart';

class SignatureCreatorScreen extends ConsumerStatefulWidget {
  final String? signatureId;

  const SignatureCreatorScreen({super.key, this.signatureId});

  @override
  ConsumerState<SignatureCreatorScreen> createState() =>
      _SignatureCreatorScreenState();
}

class _SignatureCreatorScreenState
    extends ConsumerState<SignatureCreatorScreen> {
  final GlobalKey _canvasKey = GlobalKey();
  final List<List<Offset>> _strokes = [];
  List<Offset> _currentStroke = [];
  Color _penColor = Colors.black;
  double _penWidth = 3.0;
  String _signatureName = 'Signature';
  SignatureModel? _existingSignature;
  bool _isLoading = false;
  bool _isEditing = false;

  // For imported image mode
  Uint8List? _importedImage;

  @override
  void initState() {
    super.initState();
    if (widget.signatureId != null) {
      _loadExistingSignature();
    }
  }

  Future<void> _loadExistingSignature() async {
    setState(() => _isLoading = true);

    final result = await ref
        .read(signatureRepositoryProvider)
        .getSignatureById(widget.signatureId!);

    result.when(
      success: (signature) {
        setState(() {
          _existingSignature = signature;
          _signatureName = signature.name;
          _penColor = signature.color;
          _isEditing = true;
          _isLoading = false;
        });

        // Load existing image
        _loadExistingImage(signature.imagePath);
      },
      failure: (message, error) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load signature: $message')),
          );
          context.pop();
        }
      },
    );
  }

  Future<void> _loadExistingImage(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        setState(() {
          _importedImage = bytes;
        });
      }
    } catch (e) {
      AppLogger.error('Failed to load existing signature image', e);
    }
  }

  void _clear() {
    setState(() {
      _strokes.clear();
      _currentStroke = [];
      _importedImage = null;
    });
  }

  void _undo() {
    if (_strokes.isNotEmpty) {
      setState(() {
        _strokes.removeLast();
      });
    }
  }

  Future<void> _importImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty || result.files.first.path == null) {
        return;
      }

      final file = File(result.files.first.path!);
      final bytes = await file.readAsBytes();

      // Process image to make it transparent-friendly
      final processedBytes = await _processImportedImage(bytes);

      setState(() {
        _importedImage = processedBytes;
        _strokes.clear();
      });
    } catch (e, stack) {
      AppLogger.error('Failed to import image', e, stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to import image: ${e.toString()}')),
        );
      }
    }
  }

  Future<Uint8List> _processImportedImage(Uint8List bytes) async {
    final image = img.decodeImage(bytes);
    if (image == null) return bytes;

    // Make white/near-white pixels transparent
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final luminance = img.getLuminance(pixel);
        
        // If pixel is very light (near white), make it transparent
        if (luminance > 240) {
          image.setPixelRgba(x, y, 255, 255, 255, 0);
        }
      }
    }

    return Uint8List.fromList(img.encodePng(image));
  }

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pick Pen Color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: _penColor,
            onColorChanged: (color) {
              setState(() => _penColor = color);
            },
            pickerAreaHeightPercent: 0.8,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSignature() async {
    if (_strokes.isEmpty && _importedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please draw a signature or import an image')),
      );
      return;
    }

    // Prompt for name
    final controller = TextEditingController(text: _signatureName);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Signature'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'Enter signature name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      Uint8List imageBytes;

      if (_importedImage != null) {
        imageBytes = _importedImage!;
      } else {
        // Render canvas to image
        imageBytes = await _captureCanvas();
      }

      // Save to file
      final sigDir = await FileUtils.getSignaturesDirectory();
      final fileName = '${const Uuid().v4()}.png';
      final filePath = '${sigDir.path}/$fileName';
      await File(filePath).writeAsBytes(imageBytes);

      // Delete old file if editing
      if (_existingSignature != null &&
          _existingSignature!.imagePath != filePath) {
        await FileUtils.deleteFile(_existingSignature!.imagePath);
      }

      // Save to repository
      final signature = SignatureModel(
        id: _existingSignature?.id ?? const Uuid().v4(),
        name: name,
        imagePath: filePath,
        colorValue: _penColor.value,
        createdAt: _existingSignature?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = await ref
          .read(signatureRepositoryProvider)
          .saveSignature(signature);

      result.when(
        success: (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Signature saved')),
            );
            context.pop();
          }
        },
        failure: (message, error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to save: $message')),
            );
          }
        },
      );
    } catch (e, stack) {
      AppLogger.error('Failed to save signature', e, stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: ${e.toString()}')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<Uint8List> _captureCanvas() async {
    // Find bounding box of all strokes
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final stroke in _strokes) {
      for (final point in stroke) {
        minX = minX < point.dx ? minX : point.dx;
        minY = minY < point.dy ? minY : point.dy;
        maxX = maxX > point.dx ? maxX : point.dx;
        maxY = maxY > point.dy ? maxY : point.dy;
      }
    }

    // Add padding
    const padding = 20.0;
    minX -= padding;
    minY -= padding;
    maxX += padding;
    maxY += padding;

    final width = (maxX - minX).ceil();
    final height = (maxY - minY).ceil();

    // Create picture recorder
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Draw strokes with offset
    final paint = Paint()
      ..color = _penColor
      ..strokeWidth = _penWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final stroke in _strokes) {
      if (stroke.length < 2) continue;

      final path = Path();
      path.moveTo(stroke[0].dx - minX, stroke[0].dy - minY);

      for (int i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx - minX, stroke[i].dy - minY);
      }

      canvas.drawPath(path, paint);
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.abs().clamp(1, 4096), height.abs().clamp(1, 4096));
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Signature' : 'Create Signature'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_strokes.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.undo),
              onPressed: _undo,
              tooltip: 'Undo',
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _clear,
            tooltip: 'Clear',
          ),
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _isLoading ? null : _saveSignature,
            tooltip: 'Save',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Tool bar
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Row(
                    children: [
                      // Color picker
                      GestureDetector(
                        onTap: _showColorPicker,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _penColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.grey.shade400,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Pen width
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.brush, size: 20),
                            Expanded(
                              child: Slider(
                                value: _penWidth,
                                min: 1,
                                max: 10,
                                divisions: 9,
                                label: _penWidth.round().toString(),
                                onChanged: (value) {
                                  setState(() => _penWidth = value);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Import button
                      IconButton(
                        icon: const Icon(Icons.image),
                        onPressed: _importImage,
                        tooltip: 'Import Image',
                      ),
                    ],
                  ),
                ),
                // Canvas
                Expanded(
                  child: _importedImage != null
                      ? _buildImportedImagePreview()
                      : _buildDrawingCanvas(),
                ),
              ],
            ),
    );
  }

  Widget _buildDrawingCanvas() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GestureDetector(
          onPanStart: (details) {
            setState(() {
              _currentStroke = [details.localPosition];
            });
          },
          onPanUpdate: (details) {
            setState(() {
              _currentStroke.add(details.localPosition);
            });
          },
          onPanEnd: (details) {
            setState(() {
              if (_currentStroke.isNotEmpty) {
                _strokes.add(List.from(_currentStroke));
                _currentStroke = [];
              }
            });
          },
          child: RepaintBoundary(
            key: _canvasKey,
            child: CustomPaint(
              painter: _SignaturePainter(
                strokes: _strokes,
                currentStroke: _currentStroke,
                color: _penColor,
                strokeWidth: _penWidth,
              ),
              size: Size.infinite,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImportedImagePreview() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Center(
        child: Image.memory(
          _importedImage!,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset> currentStroke;
  final Color color;
  final double strokeWidth;

  _SignaturePainter({
    required this.strokes,
    required this.currentStroke,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Draw completed strokes
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke, paint);
    }

    // Draw current stroke
    if (currentStroke.isNotEmpty) {
      _drawStroke(canvas, currentStroke, paint);
    }
  }

  void _drawStroke(Canvas canvas, List<Offset> stroke, Paint paint) {
    if (stroke.length < 2) {
      if (stroke.isNotEmpty) {
        canvas.drawCircle(stroke[0], strokeWidth / 2, paint);
      }
      return;
    }

    final path = Path();
    path.moveTo(stroke[0].dx, stroke[0].dy);

    for (int i = 1; i < stroke.length; i++) {
      // Smooth curve
      if (i < stroke.length - 1) {
        final p0 = stroke[i - 1];
        final p1 = stroke[i];
        final p2 = stroke[i + 1];
        final midX = (p1.dx + p2.dx) / 2;
        final midY = (p1.dy + p2.dy) / 2;
        path.quadraticBezierTo(p1.dx, p1.dy, midX, midY);
      } else {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.currentStroke != currentStroke ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

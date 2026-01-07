import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:image/image.dart' as img;

import 'package:sign_stamp/core/providers/repositories_provider.dart';
import 'package:sign_stamp/core/utils/file_utils.dart';
import 'package:sign_stamp/core/utils/logger.dart';
import 'package:sign_stamp/features/editor/data/models/project_model.dart';
import 'package:sign_stamp/features/signature/data/models/signature_model.dart';

class EditorScreen extends ConsumerStatefulWidget {
  final String documentPath;
  final String? signatureId;
  final String? projectId;

  const EditorScreen({
    super.key,
    required this.documentPath,
    this.signatureId,
    this.projectId,
  });

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  final GlobalKey _canvasKey = GlobalKey();

  // Document
  ui.Image? _documentImage;
  Size? _documentSize;

  // Signature
  SignatureModel? _signature;
  ui.Image? _signatureImage;
  Size? _signatureSize;

  // Transform state
  Offset _signaturePosition = const Offset(100, 100);
  double _signatureRotation = 0;
  double _signatureScale = 0.5;
  double _signatureOpacity = 1.0;
  SignatureColorMode _colorMode = SignatureColorMode.original;

  // Interaction state
  bool _isDragging = false;
  Offset? _lastFocalPoint;
  double? _lastScale;
  double? _lastRotation;

  // Project
  ProjectModel? _project;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeEditor();
  }

  Future<void> _initializeEditor() async {
    try {
      // Load existing project if provided
      if (widget.projectId != null) {
        final projectResult = await ref
            .read(projectRepositoryProvider)
            .getProjectById(widget.projectId!);

        if (projectResult.isSuccess) {
          _project = projectResult.valueOrNull;
          if (_project != null) {
            _signaturePosition = _project!.signatureTransform?.translation ??
                const Offset(100, 100);
            _signatureRotation = _project!.signatureTransform?.rotation ?? 0;
            _signatureScale = _project!.signatureTransform?.scale ?? 0.5;
            _signatureOpacity = _project!.signatureOpacity;
            _colorMode = _project!.signatureColorMode;

            // Load signature
            if (_project!.signatureId != null) {
              await _loadSignature(_project!.signatureId!);
            }
          }
        }
      }

      // Load document
      await _loadDocument();

      // Load signature if specified
      if (widget.signatureId != null && _signature == null) {
        await _loadSignature(widget.signatureId!);
      }

      setState(() => _isLoading = false);
    } catch (e, stack) {
      AppLogger.error('Failed to initialize editor', e, stack);
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _loadDocument() async {
    final path = _project?.documentPath ?? widget.documentPath;
    final file = File(path);
    final bytes = await file.readAsBytes();

    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();

    setState(() {
      _documentImage = frame.image;
      _documentSize = Size(
        frame.image.width.toDouble(),
        frame.image.height.toDouble(),
      );
    });
  }

  Future<void> _loadSignature(String signatureId) async {
    final result =
        await ref.read(signatureRepositoryProvider).getSignatureById(signatureId);

    if (result.isSuccess) {
      final signature = result.valueOrNull!;
      final file = File(signature.imagePath);
      final bytes = await file.readAsBytes();

      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();

      setState(() {
        _signature = signature;
        _signatureImage = frame.image;
        _signatureSize = Size(
          frame.image.width.toDouble(),
          frame.image.height.toDouble(),
        );
      });
    }
  }

  Future<void> _selectSignature() async {
    await context.push('/signatures?selectMode=true');
    // Reload if signature was selected (we'll get notified via navigation)
  }

  Future<void> _saveProject() async {
    if (_documentImage == null) return;

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final project = ProjectModel(
        id: _project?.id ?? const Uuid().v4(),
        name: _project?.name ?? 'Project ${now.millisecondsSinceEpoch}',
        documentPath: _project?.documentPath ?? widget.documentPath,
        documentType: DocumentType.image,
        signatureId: _signature?.id,
        signatureTransform: SignatureTransform(
          translateX: _signaturePosition.dx,
          translateY: _signaturePosition.dy,
          rotation: _signatureRotation,
          scale: _signatureScale,
        ),
        signatureColorMode: _colorMode,
        signatureOpacity: _signatureOpacity,
        createdAt: _project?.createdAt ?? now,
        updatedAt: now,
        isDraft: true,
      );

      await ref.read(projectRepositoryProvider).saveProject(project);
      _project = project;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Project saved')),
        );
      }
    } catch (e, stack) {
      AppLogger.error('Failed to save project', e, stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: ${e.toString()}')),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _exportImage() async {
    if (_documentImage == null) return;

    setState(() => _isSaving = true);

    try {
      final bytes = await _renderFinalImage();
      if (bytes == null) {
        throw Exception('Failed to render image');
      }

      // Navigate to export screen with temporary file
      final tempDir = await FileUtils.getTempDirectory();
      final tempPath = '${tempDir.path}/export_${DateTime.now().millisecondsSinceEpoch}.png';
      await File(tempPath).writeAsBytes(bytes);

      // Save project first
      await _saveProject();

      if (mounted) {
        context.push('/export?projectId=${_project?.id}&tempPath=$tempPath');
      }
    } catch (e, stack) {
      AppLogger.error('Failed to export', e, stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: ${e.toString()}')),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<Uint8List?> _renderFinalImage() async {
    if (_documentImage == null || _documentSize == null) return null;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Draw document at full resolution
    canvas.drawImage(_documentImage!, Offset.zero, Paint());

    // Draw signature if exists
    if (_signatureImage != null && _signatureSize != null) {
      final signaturePaint = Paint()..color = Colors.white.withOpacity(_signatureOpacity);

      canvas.save();
      canvas.translate(_signaturePosition.dx, _signaturePosition.dy);
      canvas.rotate(_signatureRotation);
      canvas.scale(_signatureScale);

      // Center the signature on its position
      final offsetX = -_signatureSize!.width / 2;
      final offsetY = -_signatureSize!.height / 2;

      if (_colorMode == SignatureColorMode.blackAndWhite) {
        // Apply grayscale filter
        final colorFilter = ColorFilter.matrix([
          0.299, 0.587, 0.114, 0, 0,
          0.299, 0.587, 0.114, 0, 0,
          0.299, 0.587, 0.114, 0, 0,
          0, 0, 0, _signatureOpacity, 0,
        ]);
        signaturePaint.colorFilter = colorFilter;
      }

      canvas.drawImage(
        _signatureImage!,
        Offset(offsetX, offsetY),
        signaturePaint,
      );
      canvas.restore();
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      _documentSize!.width.toInt(),
      _documentSize!.height.toInt(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return byteData?.buffer.asUint8List();
  }

  void _onScaleStart(ScaleStartDetails details) {
    _lastFocalPoint = details.localFocalPoint;
    _lastScale = _signatureScale;
    _lastRotation = _signatureRotation;
  }

  void _onScaleUpdate(ScaleUpdateDetails details, Size containerSize, double scale, Offset offset) {
    final focalPoint = details.localFocalPoint;

    // Convert screen coordinates to image coordinates
    final imageX = (focalPoint.dx - offset.dx) / scale;
    final imageY = (focalPoint.dy - offset.dy) / scale;

    // Check if touch is on signature
    final signatureBounds = Rect.fromCenter(
      center: _signaturePosition,
      width: (_signatureSize?.width ?? 100) * _signatureScale,
      height: (_signatureSize?.height ?? 100) * _signatureScale,
    );

    final touchPoint = Offset(imageX, imageY);
    final isOnSignature = signatureBounds.contains(touchPoint);

    if (isOnSignature || _isDragging) {
      _isDragging = true;

      setState(() {
        // Handle translation
        if (_lastFocalPoint != null) {
          final delta = (focalPoint - _lastFocalPoint!) / scale;
          _signaturePosition += delta;
        }

        // Handle scale
        if (details.scale != 1.0 && _lastScale != null) {
          _signatureScale = (_lastScale! * details.scale).clamp(0.1, 5.0);
        }

        // Handle rotation
        if (details.rotation != 0 && _lastRotation != null) {
          _signatureRotation = _lastRotation! + details.rotation;
        }
      });

      _lastFocalPoint = focalPoint;
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _isDragging = false;
    _lastFocalPoint = null;
    _lastScale = null;
    _lastRotation = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Document'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_outlined),
            onPressed: _isSaving ? null : _saveProject,
            tooltip: 'Save Draft',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _isSaving ? null : _exportImage,
            tooltip: 'Export',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _buildCanvas(),
                ),
                _buildToolbar(),
              ],
            ),
    );
  }

  Widget _buildCanvas() {
    if (_documentImage == null) {
      return const Center(child: Text('No document loaded'));
    }

    return Container(
      color: Colors.grey.shade200,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate scale to fit document in container
          final containerSize = constraints.biggest;
          final docAspect = _documentSize!.width / _documentSize!.height;
          final containerAspect = containerSize.width / containerSize.height;

          double scale;
          Offset offset;

          if (docAspect > containerAspect) {
            scale = containerSize.width / _documentSize!.width;
            offset = Offset(
              0,
              (containerSize.height - _documentSize!.height * scale) / 2,
            );
          } else {
            scale = containerSize.height / _documentSize!.height;
            offset = Offset(
              (containerSize.width - _documentSize!.width * scale) / 2,
              0,
            );
          }

          return GestureDetector(
            onScaleStart: _signatureImage != null ? _onScaleStart : null,
            onScaleUpdate: _signatureImage != null
                ? (details) => _onScaleUpdate(details, containerSize, scale, offset)
                : null,
            onScaleEnd: _signatureImage != null ? _onScaleEnd : null,
            child: RepaintBoundary(
              key: _canvasKey,
              child: CustomPaint(
                painter: _EditorPainter(
                  documentImage: _documentImage!,
                  signatureImage: _signatureImage,
                  signaturePosition: _signaturePosition,
                  signatureRotation: _signatureRotation,
                  signatureScale: _signatureScale,
                  signatureOpacity: _signatureOpacity,
                  signatureSize: _signatureSize,
                  colorMode: _colorMode,
                  scale: scale,
                  offset: offset,
                ),
                size: containerSize,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Signature selection
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectSignature,
                    icon: const Icon(Icons.draw),
                    label: Text(
                      _signature != null
                          ? _signature!.name
                          : 'Select Signature',
                    ),
                  ),
                ),
              ],
            ),
            if (_signature != null) ...[
              const SizedBox(height: 16),
              // Opacity slider
              Row(
                children: [
                  const Icon(Icons.opacity, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Slider(
                      value: _signatureOpacity,
                      min: 0.1,
                      max: 1.0,
                      divisions: 9,
                      label: '${(_signatureOpacity * 100).round()}%',
                      onChanged: (value) {
                        setState(() => _signatureOpacity = value);
                      },
                    ),
                  ),
                ],
              ),
              // Color mode toggle
              Row(
                children: [
                  const Icon(Icons.color_lens, size: 20),
                  const SizedBox(width: 16),
                  ChoiceChip(
                    label: const Text('Original'),
                    selected: _colorMode == SignatureColorMode.original,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _colorMode = SignatureColorMode.original);
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('B/W'),
                    selected: _colorMode == SignatureColorMode.blackAndWhite,
                    onSelected: (selected) {
                      if (selected) {
                        setState(
                          () => _colorMode = SignatureColorMode.blackAndWhite,
                        );
                      }
                    },
                  ),
                  const Spacer(),
                  // Reset transform
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () {
                      setState(() {
                        _signaturePosition = Offset(
                          _documentSize!.width / 2,
                          _documentSize!.height / 2,
                        );
                        _signatureRotation = 0;
                        _signatureScale = 0.5;
                      });
                    },
                    tooltip: 'Reset Position',
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EditorPainter extends CustomPainter {
  final ui.Image documentImage;
  final ui.Image? signatureImage;
  final Offset signaturePosition;
  final double signatureRotation;
  final double signatureScale;
  final double signatureOpacity;
  final Size? signatureSize;
  final SignatureColorMode colorMode;
  final double scale;
  final Offset offset;

  _EditorPainter({
    required this.documentImage,
    required this.signatureImage,
    required this.signaturePosition,
    required this.signatureRotation,
    required this.signatureScale,
    required this.signatureOpacity,
    required this.signatureSize,
    required this.colorMode,
    required this.scale,
    required this.offset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(scale);

    // Draw document
    canvas.drawImage(documentImage, Offset.zero, Paint());

    // Draw signature
    if (signatureImage != null && signatureSize != null) {
      canvas.save();
      canvas.translate(signaturePosition.dx, signaturePosition.dy);
      canvas.rotate(signatureRotation);
      canvas.scale(signatureScale);

      final signaturePaint = Paint()..color = Colors.white.withOpacity(signatureOpacity);

      if (colorMode == SignatureColorMode.blackAndWhite) {
        signaturePaint.colorFilter = ColorFilter.matrix([
          0.299, 0.587, 0.114, 0, 0,
          0.299, 0.587, 0.114, 0, 0,
          0.299, 0.587, 0.114, 0, 0,
          0, 0, 0, signatureOpacity, 0,
        ]);
      }

      canvas.drawImage(
        signatureImage!,
        Offset(-signatureSize!.width / 2, -signatureSize!.height / 2),
        signaturePaint,
      );

      // Draw selection border
      final borderPaint = Paint()
        ..color = Colors.blue.withOpacity(0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 / signatureScale;

      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: signatureSize!.width,
          height: signatureSize!.height,
        ),
        borderPaint,
      );

      // Draw corner handles
      final handlePaint = Paint()..color = Colors.blue;
      const handleSize = 8.0;
      final corners = [
        Offset(-signatureSize!.width / 2, -signatureSize!.height / 2),
        Offset(signatureSize!.width / 2, -signatureSize!.height / 2),
        Offset(signatureSize!.width / 2, signatureSize!.height / 2),
        Offset(-signatureSize!.width / 2, signatureSize!.height / 2),
      ];

      for (final corner in corners) {
        canvas.drawCircle(corner, handleSize / signatureScale, handlePaint);
      }

      canvas.restore();
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _EditorPainter oldDelegate) {
    return oldDelegate.signaturePosition != signaturePosition ||
        oldDelegate.signatureRotation != signatureRotation ||
        oldDelegate.signatureScale != signatureScale ||
        oldDelegate.signatureOpacity != signatureOpacity ||
        oldDelegate.colorMode != colorMode ||
        oldDelegate.signatureImage != signatureImage;
  }
}

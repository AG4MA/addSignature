import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:image/image.dart' as img;

import 'package:sign_stamp/core/providers/repositories_provider.dart';
import 'package:sign_stamp/core/utils/file_utils.dart';
import 'package:sign_stamp/core/utils/logger.dart';
import 'package:sign_stamp/features/editor/data/models/project_model.dart';
import 'package:sign_stamp/features/signature/data/models/signature_model.dart';

enum ExportFormat { png, jpg, pdf }

enum ExportResolution { original, hd2k, compressed }

class ExportScreen extends ConsumerStatefulWidget {
  final String projectId;

  const ExportScreen({super.key, required this.projectId});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  ProjectModel? _project;
  Uint8List? _previewBytes;
  bool _isLoading = true;
  bool _isExporting = false;

  ExportFormat _format = ExportFormat.png;
  ExportResolution _resolution = ExportResolution.original;
  int _jpgQuality = 90;

  @override
  void initState() {
    super.initState();
    _loadProject();
  }

  Future<void> _loadProject() async {
    try {
      final result = await ref
          .read(projectRepositoryProvider)
          .getProjectById(widget.projectId);

      if (result.isFailure) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load project: ${result.errorOrNull}')),
          );
          context.pop();
        }
        return;
      }

      _project = result.valueOrNull;

      // Generate preview
      await _generatePreview();

      setState(() => _isLoading = false);
    } catch (e, stack) {
      AppLogger.error('Failed to load project', e, stack);
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _generatePreview() async {
    if (_project == null) return;

    try {
      // Load document and signature
      final docFile = File(_project!.documentPath);
      final docBytes = await docFile.readAsBytes();

      // Decode document
      final docImage = img.decodeImage(docBytes);
      if (docImage == null) return;

      // Load and apply signature
      if (_project!.signatureId != null && _project!.signatureTransform != null) {
        final sigResult = await ref
            .read(signatureRepositoryProvider)
            .getSignatureById(_project!.signatureId!);

        if (sigResult.isSuccess) {
          final signature = sigResult.valueOrNull!;
          final sigFile = File(signature.imagePath);
          final sigBytes = await sigFile.readAsBytes();
          final sigImage = img.decodeImage(sigBytes);

          if (sigImage != null) {
            // Apply transform and composite
            final transform = _project!.signatureTransform!;
            final composited = _compositeImages(
              docImage,
              sigImage,
              transform,
              _project!.signatureOpacity,
              _project!.signatureColorMode,
            );

            _previewBytes = Uint8List.fromList(img.encodePng(composited));
          }
        }
      }

      _previewBytes ??= docBytes;
    } catch (e, stack) {
      AppLogger.error('Failed to generate preview', e, stack);
    }
  }

  img.Image _compositeImages(
    img.Image doc,
    img.Image sig,
    SignatureTransform transform,
    double opacity,
    SignatureColorMode colorMode,
  ) {
    // Create output image
    final result = img.Image.from(doc);

    // Scale signature
    final scaledWidth = (sig.width * transform.scale).round();
    final scaledHeight = (sig.height * transform.scale).round();
    var scaledSig = img.copyResize(
      sig,
      width: scaledWidth,
      height: scaledHeight,
      interpolation: img.Interpolation.linear,
    );

    // Apply B/W if needed
    if (colorMode == SignatureColorMode.blackAndWhite) {
      scaledSig = img.grayscale(scaledSig);
    }

    // Calculate position (centered on transform point)
    final posX = (transform.translateX - scaledWidth / 2).round();
    final posY = (transform.translateY - scaledHeight / 2).round();

    // Composite with alpha
    for (int y = 0; y < scaledSig.height; y++) {
      for (int x = 0; x < scaledSig.width; x++) {
        final destX = posX + x;
        final destY = posY + y;

        if (destX >= 0 && destX < doc.width && destY >= 0 && destY < doc.height) {
          final sigPixel = scaledSig.getPixel(x, y);
          final sigAlpha = sigPixel.a / 255.0 * opacity;

          if (sigAlpha > 0) {
            final docPixel = result.getPixel(destX, destY);

            final r = (sigPixel.r * sigAlpha + docPixel.r * (1 - sigAlpha)).round();
            final g = (sigPixel.g * sigAlpha + docPixel.g * (1 - sigAlpha)).round();
            final b = (sigPixel.b * sigAlpha + docPixel.b * (1 - sigAlpha)).round();

            result.setPixelRgba(destX, destY, r, g, b, 255);
          }
        }
      }
    }

    return result;
  }

  Future<void> _export() async {
    if (_previewBytes == null) return;

    setState(() => _isExporting = true);

    try {
      final exportDir = await FileUtils.getExportsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      String fileName;
      Uint8List outputBytes;

      // Process based on resolution
      var image = img.decodeImage(_previewBytes!);
      if (image == null) throw Exception('Failed to decode image');

      switch (_resolution) {
        case ExportResolution.hd2k:
          final maxDim = 2048;
          if (image.width > maxDim || image.height > maxDim) {
            if (image.width > image.height) {
              image = img.copyResize(image, width: maxDim);
            } else {
              image = img.copyResize(image, height: maxDim);
            }
          }
          break;
        case ExportResolution.compressed:
          final maxDim = 1024;
          if (image.width > maxDim || image.height > maxDim) {
            if (image.width > image.height) {
              image = img.copyResize(image, width: maxDim);
            } else {
              image = img.copyResize(image, height: maxDim);
            }
          }
          break;
        case ExportResolution.original:
          // Keep original size
          break;
      }

      // Encode based on format
      switch (_format) {
        case ExportFormat.png:
          fileName = 'SignStamp_$timestamp.png';
          outputBytes = Uint8List.fromList(img.encodePng(image));
          break;
        case ExportFormat.jpg:
          fileName = 'SignStamp_$timestamp.jpg';
          outputBytes = Uint8List.fromList(
            img.encodeJpg(image, quality: _jpgQuality),
          );
          break;
        case ExportFormat.pdf:
          fileName = 'SignStamp_$timestamp.pdf';
          outputBytes = await _createPdf(image);
          break;
      }

      final outputPath = '${exportDir.path}/$fileName';
      await File(outputPath).writeAsBytes(outputBytes);

      // Mark project as not draft
      if (_project != null) {
        final updatedProject = _project!.copyWith(isDraft: false);
        await ref.read(projectRepositoryProvider).saveProject(updatedProject);
      }

      if (mounted) {
        _showExportSuccessDialog(outputPath);
      }
    } catch (e, stack) {
      AppLogger.error('Failed to export', e, stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: ${e.toString()}')),
        );
      }
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<Uint8List> _createPdf(img.Image image) async {
    final pdf = pw.Document();

    // Convert image to PDF format
    final pdfImage = pw.MemoryImage(
      Uint8List.fromList(img.encodePng(image)),
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          image.width.toDouble(),
          image.height.toDouble(),
        ),
        build: (context) {
          return pw.Center(
            child: pw.Image(pdfImage),
          );
        },
      ),
    );

    return await pdf.save();
  }

  void _showExportSuccessDialog(String filePath) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Export Complete'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your document has been exported successfully.'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _format == ExportFormat.pdf
                        ? Icons.picture_as_pdf
                        : Icons.image,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      filePath.split('/').last,
                      style: const TextStyle(fontFamily: 'monospace'),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/');
            },
            child: const Text('Done'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _shareFile(filePath);
            },
            icon: const Icon(Icons.share),
            label: const Text('Share'),
          ),
        ],
      ),
    );
  }

  Future<void> _shareFile(String filePath) async {
    try {
      final result = await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Signed document from SignStamp',
      );

      if (result.status == ShareResultStatus.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Shared successfully')),
          );
        }
      }
    } catch (e, stack) {
      AppLogger.error('Failed to share', e, stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Export'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Preview
                Expanded(
                  child: Container(
                    color: Colors.grey.shade200,
                    padding: const EdgeInsets.all(16),
                    child: _previewBytes != null
                        ? Center(
                            child: Image.memory(
                              _previewBytes!,
                              fit: BoxFit.contain,
                            ),
                          )
                        : const Center(child: Text('No preview available')),
                  ),
                ),
                // Options
                Container(
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Format',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<ExportFormat>(
                          segments: const [
                            ButtonSegment(
                              value: ExportFormat.png,
                              label: Text('PNG'),
                              icon: Icon(Icons.image),
                            ),
                            ButtonSegment(
                              value: ExportFormat.jpg,
                              label: Text('JPG'),
                              icon: Icon(Icons.photo),
                            ),
                            ButtonSegment(
                              value: ExportFormat.pdf,
                              label: Text('PDF'),
                              icon: Icon(Icons.picture_as_pdf),
                            ),
                          ],
                          selected: {_format},
                          onSelectionChanged: (values) {
                            setState(() => _format = values.first);
                          },
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Resolution',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<ExportResolution>(
                          segments: const [
                            ButtonSegment(
                              value: ExportResolution.original,
                              label: Text('Original'),
                            ),
                            ButtonSegment(
                              value: ExportResolution.hd2k,
                              label: Text('2K'),
                            ),
                            ButtonSegment(
                              value: ExportResolution.compressed,
                              label: Text('Compressed'),
                            ),
                          ],
                          selected: {_resolution},
                          onSelectionChanged: (values) {
                            setState(() => _resolution = values.first);
                          },
                        ),
                        if (_format == ExportFormat.jpg) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Text(
                                'Quality: $_jpgQuality%',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              Expanded(
                                child: Slider(
                                  value: _jpgQuality.toDouble(),
                                  min: 10,
                                  max: 100,
                                  divisions: 9,
                                  label: '$_jpgQuality%',
                                  onChanged: (value) {
                                    setState(() => _jpgQuality = value.round());
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed: _isExporting ? null : _export,
                            icon: _isExporting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.download),
                            label: Text(_isExporting ? 'Exporting...' : 'Export'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

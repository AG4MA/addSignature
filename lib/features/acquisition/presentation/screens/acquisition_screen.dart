import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import 'package:pdfx/pdfx.dart';

import 'package:sign_stamp/core/utils/file_utils.dart';
import 'package:sign_stamp/core/utils/logger.dart';

class AcquisitionScreen extends ConsumerStatefulWidget {
  final String source;

  const AcquisitionScreen({super.key, required this.source});

  @override
  ConsumerState<AcquisitionScreen> createState() => _AcquisitionScreenState();
}

class _AcquisitionScreenState extends ConsumerState<AcquisitionScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  String? _selectedFilePath;
  PdfDocument? _pdfDocument;
  int _selectedPageIndex = 0;
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleSource();
    });
  }

  @override
  void dispose() {
    _pdfDocument?.close();
    super.dispose();
  }

  Future<void> _handleSource() async {
    if (widget.source == 'camera') {
      await _captureFromCamera();
    } else {
      await _pickFile();
    }
  }

  Future<void> _captureFromCamera() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Request camera permission
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        setState(() {
          _errorMessage = 'Camera permission is required to capture documents';
          _isLoading = false;
        });
        return;
      }

      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (image == null) {
        if (mounted) {
          context.pop();
        }
        return;
      }

      // Copy to app storage
      final docDir = await FileUtils.getDocumentsDirectory();
      final fileName = '${const Uuid().v4()}.jpg';
      final savedPath = await FileUtils.copyToAppStorage(
        image.path,
        docDir,
        fileName,
      );

      setState(() {
        _selectedFilePath = savedPath;
        _isLoading = false;
      });

      // Navigate to scan screen for photo
      if (mounted) {
        context.pushReplacement('/scan?imagePath=$savedPath');
      }
    } catch (e, stack) {
      AppLogger.error('Failed to capture image', e, stack);
      setState(() {
        _errorMessage = 'Failed to capture image: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _pickFile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        if (mounted) {
          context.pop();
        }
        return;
      }

      final file = result.files.first;
      if (file.path == null) {
        setState(() {
          _errorMessage = 'Could not access the selected file';
          _isLoading = false;
        });
        return;
      }

      // Copy to app storage
      final docDir = await FileUtils.getDocumentsDirectory();
      final ext = FileUtils.getFileExtension(file.path!);
      final fileName = '${const Uuid().v4()}.$ext';
      final savedPath = await FileUtils.copyToAppStorage(
        file.path!,
        docDir,
        fileName,
      );

      setState(() {
        _selectedFilePath = savedPath;
        _isLoading = false;
      });

      if (FileUtils.isPdfFile(savedPath)) {
        await _loadPdfPreview(savedPath);
      } else {
        // For images, navigate to scan screen
        if (mounted) {
          context.pushReplacement('/scan?imagePath=$savedPath');
        }
      }
    } catch (e, stack) {
      AppLogger.error('Failed to pick file', e, stack);
      setState(() {
        _errorMessage = 'Failed to pick file: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPdfPreview(String path) async {
    try {
      setState(() => _isLoading = true);

      _pdfDocument = await PdfDocument.openFile(path);
      setState(() {
        _totalPages = _pdfDocument!.pagesCount;
        _isLoading = false;
      });
    } catch (e, stack) {
      AppLogger.error('Failed to load PDF', e, stack);
      setState(() {
        _errorMessage = 'Failed to load PDF: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _proceedWithPdfPage() async {
    if (_pdfDocument == null || _selectedFilePath == null) return;

    setState(() => _isLoading = true);

    try {
      // Render the selected page as image
      final page = await _pdfDocument!.getPage(_selectedPageIndex + 1);
      final pageImage = await page.render(
        width: page.width * 2, // 2x for better quality
        height: page.height * 2,
        format: PdfPageImageFormat.png,
      );
      await page.close();

      if (pageImage == null) {
        setState(() {
          _errorMessage = 'Failed to render PDF page';
          _isLoading = false;
        });
        return;
      }

      // Save rendered image
      final docDir = await FileUtils.getDocumentsDirectory();
      final fileName = '${const Uuid().v4()}_page${_selectedPageIndex + 1}.png';
      final imagePath = '${docDir.path}/$fileName';
      await File(imagePath).writeAsBytes(pageImage.bytes);

      if (mounted) {
        // Navigate directly to editor (no scan needed for PDF)
        context.pushReplacement(
          '/signatures?selectMode=true&returnPath=/editor&documentPath=$imagePath',
        );
      }
    } catch (e, stack) {
      AppLogger.error('Failed to process PDF page', e, stack);
      setState(() {
        _errorMessage = 'Failed to process PDF page: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.source == 'camera' ? 'Capture Document' : 'Select File'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: _buildBody(),
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
            Text('Processing...'),
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
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _handleSource,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    // PDF Page Selection UI
    if (_pdfDocument != null) {
      return _PdfPageSelector(
        document: _pdfDocument!,
        totalPages: _totalPages,
        selectedPage: _selectedPageIndex,
        onPageSelected: (index) => setState(() => _selectedPageIndex = index),
        onProceed: _proceedWithPdfPage,
      );
    }

    return const SizedBox.shrink();
  }
}

class _PdfPageSelector extends StatefulWidget {
  final PdfDocument document;
  final int totalPages;
  final int selectedPage;
  final ValueChanged<int> onPageSelected;
  final VoidCallback onProceed;

  const _PdfPageSelector({
    required this.document,
    required this.totalPages,
    required this.selectedPage,
    required this.onPageSelected,
    required this.onProceed,
  });

  @override
  State<_PdfPageSelector> createState() => _PdfPageSelectorState();
}

class _PdfPageSelectorState extends State<_PdfPageSelector> {
  final Map<int, PdfPageImage?> _pageImages = {};

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Select a page (${widget.totalPages} pages)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.7,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: widget.totalPages,
            itemBuilder: (context, index) {
              return _PageThumbnail(
                document: widget.document,
                pageIndex: index,
                isSelected: widget.selectedPage == index,
                onTap: () => widget.onPageSelected(index),
              );
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: widget.onProceed,
                icon: const Icon(Icons.check),
                label: Text('Use Page ${widget.selectedPage + 1}'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PageThumbnail extends StatefulWidget {
  final PdfDocument document;
  final int pageIndex;
  final bool isSelected;
  final VoidCallback onTap;

  const _PageThumbnail({
    required this.document,
    required this.pageIndex,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_PageThumbnail> createState() => _PageThumbnailState();
}

class _PageThumbnailState extends State<_PageThumbnail> {
  PdfPageImage? _thumbnail;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    try {
      final page = await widget.document.getPage(widget.pageIndex + 1);
      final image = await page.render(
        width: 200,
        height: 280,
        format: PdfPageImageFormat.png,
      );
      await page.close();

      if (mounted) {
        setState(() {
          _thumbnail = image;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade300,
            width: widget.isSelected ? 3 : 1,
          ),
          boxShadow: widget.isSelected
              ? [
                  BoxShadow(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            children: [
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_thumbnail != null)
                Image.memory(
                  _thumbnail!.bytes,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                )
              else
                Container(
                  color: Colors.grey.shade200,
                  child: const Center(
                    child: Icon(Icons.picture_as_pdf, size: 48),
                  ),
                ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.black54,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'Page ${widget.pageIndex + 1}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

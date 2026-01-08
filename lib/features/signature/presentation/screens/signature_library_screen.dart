import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sign_stamp/core/providers/repositories_provider.dart';
import 'package:sign_stamp/features/signature/data/models/signature_model.dart';

class SignatureLibraryScreen extends ConsumerStatefulWidget {
  final bool selectMode;

  const SignatureLibraryScreen({super.key, this.selectMode = false});

  @override
  ConsumerState<SignatureLibraryScreen> createState() =>
      _SignatureLibraryScreenState();
}

class _SignatureLibraryScreenState
    extends ConsumerState<SignatureLibraryScreen> {
  List<SignatureModel> _signatures = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSignatures();
  }

  Future<void> _loadSignatures() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await ref.read(signatureRepositoryProvider).getAllSignatures();

    result.when(
      success: (signatures) {
        setState(() {
          _signatures = signatures;
          _isLoading = false;
        });
      },
      failure: (message, error) {
        setState(() {
          _errorMessage = message;
          _isLoading = false;
        });
      },
    );
  }

  Future<void> _deleteSignature(SignatureModel signature) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Signature'),
        content: Text('Are you sure you want to delete "${signature.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(signatureRepositoryProvider).deleteSignature(signature.id);
      await _loadSignatures();
    }
  }

  Future<void> _renameSignature(SignatureModel signature) async {
    final controller = TextEditingController(text: signature.name);

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Signature'),
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

    if (newName != null && newName.isNotEmpty && newName != signature.name) {
      await ref
          .read(signatureRepositoryProvider)
          .renameSignature(signature.id, newName);
      await _loadSignatures();
    }
  }

  void _selectSignature(SignatureModel signature) {
    final uri = GoRouterState.of(context).uri;
    final documentPath = uri.queryParameters['documentPath'];

    if (documentPath != null) {
      context.pushReplacement(
        '/editor?documentPath=$documentPath&signatureId=${signature.id}',
      );
    } else {
      context.pop(signature);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.selectMode ? 'Select Signature' : 'My Signatures'),
        leading: IconButton(
          icon: Icon(widget.selectMode ? Icons.close : Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final uri = GoRouterState.of(context).uri;
          final documentPath = uri.queryParameters['documentPath'];
          
          // After creating signature, come back here with the same document
          final result = await context.push<SignatureModel>('/signature-creator');
          await _loadSignatures();
          
          // If a signature was created and we're in select mode, use it automatically
          if (result != null && widget.selectMode && documentPath != null) {
            if (mounted) {
              context.pushReplacement(
                '/editor?documentPath=$documentPath&signatureId=${result.id}',
              );
            }
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Create'),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(_errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadSignatures,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_signatures.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.draw_outlined,
              size: 80,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'No Signatures Yet',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first signature to get started',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _signatures.length,
      itemBuilder: (context, index) {
        final signature = _signatures[index];
        return _SignatureCard(
          signature: signature,
          selectMode: widget.selectMode,
          onTap: () => widget.selectMode
              ? _selectSignature(signature)
              : context.push('/signature-creator?id=${signature.id}'),
          onDelete: () => _deleteSignature(signature),
          onRename: () => _renameSignature(signature),
        );
      },
    );
  }
}

class _SignatureCard extends StatelessWidget {
  final SignatureModel signature;
  final bool selectMode;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onRename;

  const _SignatureCard({
    required this.signature,
    required this.selectMode,
    required this.onTap,
    required this.onDelete,
    required this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(12),
                child: _buildPreview(),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      signature.name,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!selectMode)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onSelected: (value) {
                        switch (value) {
                          case 'rename':
                            onRename();
                            break;
                          case 'delete':
                            onDelete();
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'rename',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 20),
                              SizedBox(width: 8),
                              Text('Rename'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete,
                                size: 20,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Delete',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    final file = File(signature.imagePath);

    return FutureBuilder<bool>(
      future: file.exists(),
      builder: (context, snapshot) {
        if (snapshot.data == true) {
          return Image.file(
            file,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stack) {
              return const Center(
                child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
              );
            },
          );
        }
        return const Center(
          child: Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
        );
      },
    );
  }
}

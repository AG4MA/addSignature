import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sign_stamp/core/utils/logger.dart';
import 'package:sign_stamp/core/utils/result.dart';
import 'package:sign_stamp/features/signature/data/models/signature_model.dart';

class SignatureRepository {
  static const String _signaturesFileName = 'signatures.json';
  List<SignatureModel>? _cachedSignatures;

  Future<File> _getSignaturesFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_signaturesFileName');
  }

  Future<Result<List<SignatureModel>>> getAllSignatures() async {
    try {
      if (_cachedSignatures != null) {
        return Success(List.from(_cachedSignatures!));
      }

      final file = await _getSignaturesFile();
      if (!await file.exists()) {
        _cachedSignatures = [];
        return const Success([]);
      }

      final content = await file.readAsString();
      final List<dynamic> jsonList = json.decode(content);
      _cachedSignatures = jsonList
          .map((e) => SignatureModel.fromJson(e as Map<String, dynamic>))
          .toList();

      return Success(List.from(_cachedSignatures!));
    } catch (e, stack) {
      AppLogger.error('Failed to load signatures', e, stack);
      return Failure('Failed to load signatures: ${e.toString()}', e);
    }
  }

  Future<Result<SignatureModel>> getSignatureById(String id) async {
    try {
      final signaturesResult = await getAllSignatures();
      if (signaturesResult.isFailure) {
        return Failure(signaturesResult.errorOrNull ?? 'Unknown error');
      }

      final signatures = signaturesResult.valueOrNull!;
      final signature = signatures.where((s) => s.id == id).firstOrNull;
      
      if (signature == null) {
        return Failure('Signature not found');
      }
      
      return Success(signature);
    } catch (e, stack) {
      AppLogger.error('Failed to get signature', e, stack);
      return Failure('Failed to get signature: ${e.toString()}', e);
    }
  }

  Future<Result<SignatureModel>> saveSignature(SignatureModel signature) async {
    try {
      final signaturesResult = await getAllSignatures();
      if (signaturesResult.isFailure) {
        return Failure(signaturesResult.errorOrNull ?? 'Unknown error');
      }

      final signatures = signaturesResult.valueOrNull!;
      final existingIndex = signatures.indexWhere((s) => s.id == signature.id);

      if (existingIndex >= 0) {
        signatures[existingIndex] = signature;
      } else {
        signatures.add(signature);
      }

      await _saveSignatures(signatures);
      _cachedSignatures = signatures;

      return Success(signature);
    } catch (e, stack) {
      AppLogger.error('Failed to save signature', e, stack);
      return Failure('Failed to save signature: ${e.toString()}', e);
    }
  }

  Future<Result<void>> deleteSignature(String id) async {
    try {
      final signaturesResult = await getAllSignatures();
      if (signaturesResult.isFailure) {
        return Failure(signaturesResult.errorOrNull ?? 'Unknown error');
      }

      final signatures = signaturesResult.valueOrNull!;
      final signature = signatures.where((s) => s.id == id).firstOrNull;

      if (signature != null) {
        // Delete the image file
        final imageFile = File(signature.imagePath);
        if (await imageFile.exists()) {
          await imageFile.delete();
        }

        signatures.removeWhere((s) => s.id == id);
        await _saveSignatures(signatures);
        _cachedSignatures = signatures;
      }

      return const Success(null);
    } catch (e, stack) {
      AppLogger.error('Failed to delete signature', e, stack);
      return Failure('Failed to delete signature: ${e.toString()}', e);
    }
  }

  Future<Result<SignatureModel>> renameSignature(
    String id,
    String newName,
  ) async {
    try {
      final signaturesResult = await getAllSignatures();
      if (signaturesResult.isFailure) {
        return Failure(signaturesResult.errorOrNull ?? 'Unknown error');
      }

      final signatures = signaturesResult.valueOrNull!;
      final index = signatures.indexWhere((s) => s.id == id);

      if (index < 0) {
        return const Failure('Signature not found');
      }

      final updatedSignature = signatures[index].copyWith(
        name: newName,
        updatedAt: DateTime.now(),
      );
      signatures[index] = updatedSignature;

      await _saveSignatures(signatures);
      _cachedSignatures = signatures;

      return Success(updatedSignature);
    } catch (e, stack) {
      AppLogger.error('Failed to rename signature', e, stack);
      return Failure('Failed to rename signature: ${e.toString()}', e);
    }
  }

  Future<void> _saveSignatures(List<SignatureModel> signatures) async {
    final file = await _getSignaturesFile();
    final jsonList = signatures.map((s) => s.toJson()).toList();
    await file.writeAsString(json.encode(jsonList));
  }

  void clearCache() {
    _cachedSignatures = null;
  }
}

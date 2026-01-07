import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sign_stamp/features/signature/data/repositories/signature_repository.dart';
import 'package:sign_stamp/features/editor/data/repositories/project_repository.dart';

// Signature Repository Provider
final signatureRepositoryProvider = Provider<SignatureRepository>((ref) {
  return SignatureRepository();
});

// Project Repository Provider
final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepository();
});

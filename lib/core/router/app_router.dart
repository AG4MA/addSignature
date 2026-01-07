import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sign_stamp/features/acquisition/presentation/screens/acquisition_screen.dart';
import 'package:sign_stamp/features/editor/presentation/screens/editor_screen.dart';
import 'package:sign_stamp/features/export/presentation/screens/export_screen.dart';
import 'package:sign_stamp/features/home/presentation/screens/home_screen.dart';
import 'package:sign_stamp/features/scan/presentation/screens/scan_screen.dart';
import 'package:sign_stamp/features/signature/presentation/screens/signature_creator_screen.dart';
import 'package:sign_stamp/features/signature/presentation/screens/signature_library_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/acquisition',
        name: 'acquisition',
        builder: (context, state) {
          final source = state.uri.queryParameters['source'] ?? 'camera';
          return AcquisitionScreen(source: source);
        },
      ),
      GoRoute(
        path: '/scan',
        name: 'scan',
        builder: (context, state) {
          final imagePath = state.uri.queryParameters['imagePath'] ?? '';
          return ScanScreen(imagePath: imagePath);
        },
      ),
      GoRoute(
        path: '/signatures',
        name: 'signatures',
        builder: (context, state) {
          final selectMode =
              state.uri.queryParameters['selectMode'] == 'true';
          return SignatureLibraryScreen(selectMode: selectMode);
        },
      ),
      GoRoute(
        path: '/signature-creator',
        name: 'signature-creator',
        builder: (context, state) {
          final signatureId = state.uri.queryParameters['id'];
          return SignatureCreatorScreen(signatureId: signatureId);
        },
      ),
      GoRoute(
        path: '/editor',
        name: 'editor',
        builder: (context, state) {
          final documentPath =
              state.uri.queryParameters['documentPath'] ?? '';
          final signatureId = state.uri.queryParameters['signatureId'];
          final projectId = state.uri.queryParameters['projectId'];
          return EditorScreen(
            documentPath: documentPath,
            signatureId: signatureId,
            projectId: projectId,
          );
        },
      ),
      GoRoute(
        path: '/export',
        name: 'export',
        builder: (context, state) {
          final projectId = state.uri.queryParameters['projectId'] ?? '';
          return ExportScreen(projectId: projectId);
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Error')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Page not found: ${state.uri.path}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
});

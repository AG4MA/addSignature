import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sign_stamp/core/utils/logger.dart';
import 'package:sign_stamp/core/utils/result.dart';
import 'package:sign_stamp/features/editor/data/models/project_model.dart';

class ProjectRepository {
  static const String _projectsFileName = 'projects.json';
  List<ProjectModel>? _cachedProjects;

  Future<File> _getProjectsFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_projectsFileName');
  }

  Future<Result<List<ProjectModel>>> getAllProjects() async {
    try {
      if (_cachedProjects != null) {
        return Success(List.from(_cachedProjects!));
      }

      final file = await _getProjectsFile();
      if (!await file.exists()) {
        _cachedProjects = [];
        return const Success([]);
      }

      final content = await file.readAsString();
      final List<dynamic> jsonList = json.decode(content);
      _cachedProjects = jsonList
          .map((e) => ProjectModel.fromJson(e as Map<String, dynamic>))
          .toList();

      return Success(List.from(_cachedProjects!));
    } catch (e, stack) {
      AppLogger.error('Failed to load projects', e, stack);
      return Failure('Failed to load projects: ${e.toString()}', e);
    }
  }

  Future<Result<List<ProjectModel>>> getDraftProjects() async {
    final result = await getAllProjects();
    return result.map(
      (projects) => projects.where((p) => p.isDraft).toList(),
    );
  }

  Future<Result<ProjectModel>> getProjectById(String id) async {
    try {
      final projectsResult = await getAllProjects();
      if (projectsResult.isFailure) {
        return Failure(projectsResult.errorOrNull ?? 'Unknown error');
      }

      final projects = projectsResult.valueOrNull!;
      final project = projects.where((p) => p.id == id).firstOrNull;

      if (project == null) {
        return const Failure('Project not found');
      }

      return Success(project);
    } catch (e, stack) {
      AppLogger.error('Failed to get project', e, stack);
      return Failure('Failed to get project: ${e.toString()}', e);
    }
  }

  Future<Result<ProjectModel>> saveProject(ProjectModel project) async {
    try {
      final projectsResult = await getAllProjects();
      if (projectsResult.isFailure) {
        return Failure(projectsResult.errorOrNull ?? 'Unknown error');
      }

      final projects = projectsResult.valueOrNull!;
      final existingIndex = projects.indexWhere((p) => p.id == project.id);

      final updatedProject = project.copyWith(updatedAt: DateTime.now());

      if (existingIndex >= 0) {
        projects[existingIndex] = updatedProject;
      } else {
        projects.add(updatedProject);
      }

      await _saveProjects(projects);
      _cachedProjects = projects;

      return Success(updatedProject);
    } catch (e, stack) {
      AppLogger.error('Failed to save project', e, stack);
      return Failure('Failed to save project: ${e.toString()}', e);
    }
  }

  Future<Result<void>> deleteProject(String id) async {
    try {
      final projectsResult = await getAllProjects();
      if (projectsResult.isFailure) {
        return Failure(projectsResult.errorOrNull ?? 'Unknown error');
      }

      final projects = projectsResult.valueOrNull!;
      final project = projects.where((p) => p.id == id).firstOrNull;

      if (project != null) {
        // Delete the document file if it's in app storage
        final docFile = File(project.documentPath);
        if (await docFile.exists()) {
          final appDir = await getApplicationDocumentsDirectory();
          if (project.documentPath.startsWith(appDir.path)) {
            await docFile.delete();
          }
        }

        projects.removeWhere((p) => p.id == id);
        await _saveProjects(projects);
        _cachedProjects = projects;
      }

      return const Success(null);
    } catch (e, stack) {
      AppLogger.error('Failed to delete project', e, stack);
      return Failure('Failed to delete project: ${e.toString()}', e);
    }
  }

  Future<void> _saveProjects(List<ProjectModel> projects) async {
    final file = await _getProjectsFile();
    final jsonList = projects.map((p) => p.toJson()).toList();
    await file.writeAsString(json.encode(jsonList));
  }

  void clearCache() {
    _cachedProjects = null;
  }
}

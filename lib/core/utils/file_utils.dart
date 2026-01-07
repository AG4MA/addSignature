import 'dart:io';
import 'package:path_provider/path_provider.dart';

class FileUtils {
  static Future<Directory> getAppDocumentsDirectory() async {
    return await getApplicationDocumentsDirectory();
  }

  static Future<Directory> getSignaturesDirectory() async {
    final appDir = await getAppDocumentsDirectory();
    final sigDir = Directory('${appDir.path}/signatures');
    if (!await sigDir.exists()) {
      await sigDir.create(recursive: true);
    }
    return sigDir;
  }

  static Future<Directory> getDocumentsDirectory() async {
    final appDir = await getAppDocumentsDirectory();
    final docDir = Directory('${appDir.path}/documents');
    if (!await docDir.exists()) {
      await docDir.create(recursive: true);
    }
    return docDir;
  }

  static Future<Directory> getProjectsDirectory() async {
    final appDir = await getAppDocumentsDirectory();
    final projDir = Directory('${appDir.path}/projects');
    if (!await projDir.exists()) {
      await projDir.create(recursive: true);
    }
    return projDir;
  }

  static Future<Directory> getExportsDirectory() async {
    final appDir = await getAppDocumentsDirectory();
    final expDir = Directory('${appDir.path}/exports');
    if (!await expDir.exists()) {
      await expDir.create(recursive: true);
    }
    return expDir;
  }

  static Future<Directory> getTempDirectory() async {
    final tempDir = await getTemporaryDirectory();
    final appTempDir = Directory('${tempDir.path}/sign_stamp');
    if (!await appTempDir.exists()) {
      await appTempDir.create(recursive: true);
    }
    return appTempDir;
  }

  static Future<void> deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  static Future<void> deleteDirectory(String path) async {
    final dir = Directory(path);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  static Future<String> copyToAppStorage(
    String sourcePath,
    Directory targetDir,
    String fileName,
  ) async {
    final sourceFile = File(sourcePath);
    final targetPath = '${targetDir.path}/$fileName';
    await sourceFile.copy(targetPath);
    return targetPath;
  }

  static String getFileExtension(String path) {
    final lastDot = path.lastIndexOf('.');
    if (lastDot == -1) return '';
    return path.substring(lastDot + 1).toLowerCase();
  }

  static bool isImageFile(String path) {
    final ext = getFileExtension(path);
    return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(ext);
  }

  static bool isPdfFile(String path) {
    return getFileExtension(path) == 'pdf';
  }
}

import 'dart:ui';

import 'package:sign_stamp/features/signature/data/models/signature_model.dart';

/// Document type
enum DocumentType {
  image,
  pdf,
}

/// A project containing document and signature placement
class ProjectModel {
  final String id;
  final String name;
  final String documentPath;
  final DocumentType documentType;
  final int? pdfPageIndex; // For PDF documents
  final String? signatureId;
  final SignatureTransform? signatureTransform;
  final SignatureColorMode signatureColorMode;
  final double signatureOpacity;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDraft;

  const ProjectModel({
    required this.id,
    required this.name,
    required this.documentPath,
    required this.documentType,
    this.pdfPageIndex,
    this.signatureId,
    this.signatureTransform,
    this.signatureColorMode = SignatureColorMode.original,
    this.signatureOpacity = 1.0,
    required this.createdAt,
    required this.updatedAt,
    this.isDraft = true,
  });

  ProjectModel copyWith({
    String? id,
    String? name,
    String? documentPath,
    DocumentType? documentType,
    int? pdfPageIndex,
    String? signatureId,
    SignatureTransform? signatureTransform,
    SignatureColorMode? signatureColorMode,
    double? signatureOpacity,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDraft,
  }) {
    return ProjectModel(
      id: id ?? this.id,
      name: name ?? this.name,
      documentPath: documentPath ?? this.documentPath,
      documentType: documentType ?? this.documentType,
      pdfPageIndex: pdfPageIndex ?? this.pdfPageIndex,
      signatureId: signatureId ?? this.signatureId,
      signatureTransform: signatureTransform ?? this.signatureTransform,
      signatureColorMode: signatureColorMode ?? this.signatureColorMode,
      signatureOpacity: signatureOpacity ?? this.signatureOpacity,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDraft: isDraft ?? this.isDraft,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'documentPath': documentPath,
      'documentType': documentType.name,
      'pdfPageIndex': pdfPageIndex,
      'signatureId': signatureId,
      'signatureTransform': signatureTransform?.toJson(),
      'signatureColorMode': signatureColorMode.name,
      'signatureOpacity': signatureOpacity,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isDraft': isDraft,
    };
  }

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    return ProjectModel(
      id: json['id'] as String,
      name: json['name'] as String,
      documentPath: json['documentPath'] as String,
      documentType: DocumentType.values.byName(json['documentType'] as String),
      pdfPageIndex: json['pdfPageIndex'] as int?,
      signatureId: json['signatureId'] as String?,
      signatureTransform: json['signatureTransform'] != null
          ? SignatureTransform.fromJson(
              json['signatureTransform'] as Map<String, dynamic>,
            )
          : null,
      signatureColorMode: SignatureColorMode.values
          .byName(json['signatureColorMode'] as String? ?? 'original'),
      signatureOpacity: (json['signatureOpacity'] as num?)?.toDouble() ?? 1.0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      isDraft: json['isDraft'] as bool? ?? true,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProjectModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Transform data for signature placement
class SignatureTransform {
  final double translateX;
  final double translateY;
  final double rotation; // in radians
  final double scale;

  const SignatureTransform({
    this.translateX = 0,
    this.translateY = 0,
    this.rotation = 0,
    this.scale = 1.0,
  });

  Offset get translation => Offset(translateX, translateY);

  SignatureTransform copyWith({
    double? translateX,
    double? translateY,
    double? rotation,
    double? scale,
  }) {
    return SignatureTransform(
      translateX: translateX ?? this.translateX,
      translateY: translateY ?? this.translateY,
      rotation: rotation ?? this.rotation,
      scale: scale ?? this.scale,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'translateX': translateX,
      'translateY': translateY,
      'rotation': rotation,
      'scale': scale,
    };
  }

  factory SignatureTransform.fromJson(Map<String, dynamic> json) {
    return SignatureTransform(
      translateX: (json['translateX'] as num).toDouble(),
      translateY: (json['translateY'] as num).toDouble(),
      rotation: (json['rotation'] as num).toDouble(),
      scale: (json['scale'] as num).toDouble(),
    );
  }

  static const SignatureTransform identity = SignatureTransform();
}

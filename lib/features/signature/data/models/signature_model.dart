import 'dart:ui';

/// Represents a saved signature
class SignatureModel {
  final String id;
  final String name;
  final String imagePath;
  final int colorValue; // ARGB color
  final DateTime createdAt;
  final DateTime updatedAt;

  const SignatureModel({
    required this.id,
    required this.name,
    required this.imagePath,
    required this.colorValue,
    required this.createdAt,
    required this.updatedAt,
  });

  Color get color => Color(colorValue);

  SignatureModel copyWith({
    String? id,
    String? name,
    String? imagePath,
    int? colorValue,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SignatureModel(
      id: id ?? this.id,
      name: name ?? this.name,
      imagePath: imagePath ?? this.imagePath,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'imagePath': imagePath,
      'colorValue': colorValue,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory SignatureModel.fromJson(Map<String, dynamic> json) {
    return SignatureModel(
      id: json['id'] as String,
      name: json['name'] as String,
      imagePath: json['imagePath'] as String,
      colorValue: json['colorValue'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SignatureModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Signature color mode for export
enum SignatureColorMode {
  original,
  blackAndWhite,
}

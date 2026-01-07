# SignStamp 📝

A professional mobile app for applying signatures to documents. Capture or import documents, add your signature, and export as image or PDF.

## Features

- 📷 **Document Capture**: Use camera or import from gallery/files
- ✍️ **Signature Library**: Create and manage multiple signatures
- 🔲 **Document Scanning**: Auto-detect edges with perspective correction
- 🎨 **Signature Editor**: Position, scale, rotate with touch gestures
- 📤 **Export & Share**: PNG, JPG, or PDF with native share sheet

## Tech Stack

- **Framework**: Flutter 3.24+
- **State Management**: Riverpod
- **Navigation**: go_router
- **Storage**: File system with JSON persistence
- **PDF**: pdf & pdfx packages
- **Image Processing**: Pure Dart image package

## Project Architecture

```
lib/
├── main.dart                    # App entry point
├── core/
│   ├── providers/              # Riverpod providers
│   ├── router/                 # Navigation configuration
│   ├── theme/                  # App theming
│   └── utils/                  # Utilities (Result, Logger, etc.)
└── features/
    ├── home/                   # Home screen
    ├── acquisition/            # Document capture/import
    ├── scan/                   # Edge detection & cropping
    ├── signature/              # Signature library & creator
    ├── editor/                 # Signature placement editor
    └── export/                 # Export & sharing
```

## Getting Started

### Prerequisites

- Flutter SDK 3.24.0 or higher
- Dart SDK 3.5.0 or higher
- Android Studio / Xcode for platform builds

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/AG4MA/addSignature.git
   cd addSignature
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Create asset directories**
   ```bash
   mkdir -p assets/icons assets/images assets/fonts
   ```

4. **Run code generation** (for freezed/json_serializable if used)
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

### Running the App

**Debug mode:**
```bash
flutter run
```

**Release mode:**
```bash
flutter run --release
```

### Building for Production

**Android APK:**
```bash
flutter build apk --release
```

**Android App Bundle:**
```bash
flutter build appbundle --release
```

**iOS:**
```bash
flutter build ios --release
```

## Usage Guide

### 1. Capture Document

- Tap "Capture Document" to use camera
- Or tap "Open File" to import image/PDF

### 2. Crop Document (Photos only)

- Drag corners to adjust crop area
- Tap "Apply Crop" to straighten document
- Tap "Skip" to use original image

### 3. Select/Create Signature

- View existing signatures in library
- Create new signature by drawing or importing
- Tap signature to select for document

### 4. Edit Placement

- Drag to position signature
- Pinch to scale
- Rotate with two-finger gesture
- Adjust opacity with slider
- Toggle color/B&W mode

### 5. Export

- Choose format: PNG, JPG, or PDF
- Select resolution
- Tap Export to save
- Use Share to send directly

## Testing

**Run unit tests:**
```bash
flutter test
```

**Run specific test file:**
```bash
flutter test test/core/utils/transform_utils_test.dart
```

**Run with coverage:**
```bash
flutter test --coverage
```

## API Reference

### SignatureModel

```dart
SignatureModel(
  id: String,
  name: String,
  imagePath: String,
  colorValue: int,
  createdAt: DateTime,
  updatedAt: DateTime,
)
```

### ProjectModel

```dart
ProjectModel(
  id: String,
  name: String,
  documentPath: String,
  documentType: DocumentType,
  signatureId: String?,
  signatureTransform: SignatureTransform?,
  signatureColorMode: SignatureColorMode,
  signatureOpacity: double,
  createdAt: DateTime,
  updatedAt: DateTime,
  isDraft: bool,
)
```

### SignatureTransform

```dart
SignatureTransform(
  translateX: double,
  translateY: double,
  rotation: double,      // radians
  scale: double,
)
```

## Known Limitations

1. **PDF Export**: For MVP, PDF pages are converted to images before signing. Native PDF annotation is planned for future releases.

2. **Document Scanning**: Uses pure Dart implementation. For production, consider native OpenCV bridge for better accuracy.

3. **Multi-page PDF**: Currently supports single page selection. Multi-page signing architecture is ready for extension.

## Extras (Future Enhancements)

- [ ] Multi-page PDF support
- [ ] Undo/Redo in editor
- [ ] Duplicate signature on document
- [ ] Snap-to-grid alignment
- [ ] Cloud backup/sync
- [ ] Batch document processing
- [ ] OCR text recognition
- [ ] Digital certificate signing

## Permissions

### Android
- `CAMERA` - Document capture
- `READ_EXTERNAL_STORAGE` - Import files
- `WRITE_EXTERNAL_STORAGE` - Save exports

### iOS
- Camera usage
- Photo library access
- File access

## Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Flutter team for the amazing framework
- Riverpod for elegant state management
- All open-source contributors

---

Built with ❤️ using Flutter

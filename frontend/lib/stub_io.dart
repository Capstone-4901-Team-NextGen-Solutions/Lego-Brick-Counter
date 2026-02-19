// stub_io.dart
// Stub for web platform where dart:io is unavailable.
// The conditional import in main.dart picks this on web, and dart:io on native.

class File {
  final String path;
  File(this.path);
}

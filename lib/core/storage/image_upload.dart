import 'dart:typed_data';

/// Only these image types may be uploaded. SVG is deliberately excluded: the
/// avatar/group buckets are public, and an SVG can carry inline script that
/// would execute when the file is opened directly from its storage URL.
const _allowedExtensions = {'png', 'jpeg', 'jpg', 'webp'};

const _maxUploadBytes = 5 * 1024 * 1024;

class InvalidImageException implements Exception {
  final String message;
  InvalidImageException(this.message);

  @override
  String toString() => message;
}

/// Normalizes a picked file's extension to one we accept, rejecting anything
/// else. The extension comes from a user-supplied filename, so it is never
/// trusted to build a content type on its own.
String normalizeImageExtension(String fileName) {
  final parts = fileName.toLowerCase().split('.');
  final extension = parts.length > 1 ? parts.last : '';
  if (!_allowedExtensions.contains(extension)) {
    throw InvalidImageException('Use uma imagem PNG, JPEG ou WebP.');
  }
  return extension == 'jpg' ? 'jpeg' : extension;
}

/// Verifies the bytes really are the image type the extension claims, so
/// renaming `payload.html` to `avatar.png` doesn't get it stored as an image.
void verifyImageBytes(Uint8List bytes, String extension) {
  if (bytes.length > _maxUploadBytes) {
    throw InvalidImageException('Imagem muito grande (máximo 5 MB).');
  }

  final matchesSignature = switch (extension) {
    'png' => _startsWith(bytes, [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
    'jpeg' => _startsWith(bytes, [0xFF, 0xD8, 0xFF]),
    'webp' => _startsWith(bytes, [0x52, 0x49, 0x46, 0x46]) &&
        bytes.length > 12 &&
        _startsWith(bytes.sublist(8), [0x57, 0x45, 0x42, 0x50]),
    _ => false,
  };

  if (!matchesSignature) {
    throw InvalidImageException('Arquivo de imagem inválido.');
  }
}

bool _startsWith(Uint8List bytes, List<int> signature) {
  if (bytes.length < signature.length) return false;
  for (var i = 0; i < signature.length; i++) {
    if (bytes[i] != signature[i]) return false;
  }
  return true;
}

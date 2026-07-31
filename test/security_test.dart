import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:avora/core/storage/image_upload.dart';
import 'package:avora/features/groups/presentation/group_picker.dart';
import 'package:avora/features/movies/presentation/story_share_screen.dart';

Uint8List _bytes(List<int> prefix, {int pad = 32}) =>
    Uint8List.fromList([...prefix, ...List.filled(pad, 0)]);

const _pngHeader = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
const _jpegHeader = [0xFF, 0xD8, 0xFF];

void main() {
  group('normalizeImageExtension', () {
    test('accepts allowed image types and folds jpg into jpeg', () {
      expect(normalizeImageExtension('avatar.png'), 'png');
      expect(normalizeImageExtension('AVATAR.JPG'), 'jpeg');
      expect(normalizeImageExtension('photo.webp'), 'webp');
    });

    test('rejects SVG, which could carry script into a public bucket', () {
      expect(
        () => normalizeImageExtension('payload.svg'),
        throwsA(isA<InvalidImageException>()),
      );
    });

    test('rejects extensionless and non-image files', () {
      expect(
        () => normalizeImageExtension('payload.html'),
        throwsA(isA<InvalidImageException>()),
      );
      expect(
        () => normalizeImageExtension('noextension'),
        throwsA(isA<InvalidImageException>()),
      );
    });
  });

  group('verifyImageBytes', () {
    test('accepts bytes matching the claimed type', () {
      expect(() => verifyImageBytes(_bytes(_pngHeader), 'png'), returnsNormally);
      expect(() => verifyImageBytes(_bytes(_jpegHeader), 'jpeg'), returnsNormally);
    });

    test('rejects a non-image renamed to look like an image', () {
      final html = Uint8List.fromList('<html><script>'.codeUnits);
      expect(
        () => verifyImageBytes(html, 'png'),
        throwsA(isA<InvalidImageException>()),
      );
    });

    test('rejects a JPEG masquerading as a PNG', () {
      expect(
        () => verifyImageBytes(_bytes(_jpegHeader), 'png'),
        throwsA(isA<InvalidImageException>()),
      );
    });

    test('rejects oversized uploads', () {
      final huge = Uint8List.fromList([..._pngHeader, ...List.filled(6 * 1024 * 1024, 0)]);
      expect(
        () => verifyImageBytes(huge, 'png'),
        throwsA(isA<InvalidImageException>()),
      );
    });
  });

  group('extractInviteCode', () {
    test('pulls the code out of a full invite link', () {
      expect(
        extractInviteCode('http://localhost:5695/?join=3e54529d'),
        '3e54529d',
      );
    });

    test('passes a bare code through untouched', () {
      expect(extractInviteCode('  3e54529d '), '3e54529d');
    });
  });

  group('medianRating', () {
    test('returns null with no ratings', () {
      expect(medianRating([]), isNull);
    });

    test('takes the middle value for an odd count', () {
      expect(medianRating([5, 1, 3]), 3);
    });

    test('averages the two middle values for an even count', () {
      expect(medianRating([1, 2, 4, 5]), 3);
    });

    test('resists a single outlier, unlike the mean', () {
      // Mean would be 2.0; the median keeps the group's real opinion.
      expect(medianRating([5, 5, 5, 0, 0]), 5);
    });
  });
}

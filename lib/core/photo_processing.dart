import 'dart:typed_data';

import 'package:image/image.dart' as image;

/// Decode bytes (not filename/MIME), cap allocations, resize and remove EXIF,
/// GPS and other original metadata before bytes leave the user's device.
Uint8List processProfilePhoto(Uint8List raw) {
  if (raw.length > 5242880) throw StateError('Image exceeds 5MB');
  final decoder = image.findDecoderForData(raw);
  if (decoder is! image.JpegDecoder &&
      decoder is! image.PngDecoder &&
      decoder is! image.WebPDecoder) {
    throw StateError('JPEG, PNG or WebP required');
  }
  final info = decoder!.startDecode(raw);
  if (info == null || info.width * info.height > 24000000) {
    throw StateError('Image dimensions too large');
  }
  final decoded = decoder.decodeFrame(0);
  if (decoded == null) throw StateError('Invalid image');
  final oriented = image.bakeOrientation(decoded);
  final resized = oriented.width > 1600 || oriented.height > 1600
      ? image.copyResize(
          oriented,
          width: oriented.width >= oriented.height ? 1600 : null,
          height: oriented.height > oriented.width ? 1600 : null,
        )
      : oriented;
  // Copy pixels into a new image to avoid copying the original EXIF map.
  final clean = image.Image(
    width: resized.width,
    height: resized.height,
    numChannels: 3,
  );
  image.compositeImage(clean, resized);
  return Uint8List.fromList(image.encodeJpg(clean, quality: 86));
}

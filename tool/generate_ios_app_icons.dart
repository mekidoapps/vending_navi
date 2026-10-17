// Reuse the same canonical artwork as flutter_launcher_icons' Android config.
// This command touches only the existing iOS AppIcon catalog filenames.
import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as image;

void main() {
  final source = image.decodePng(
    File('assets/icons/appicon.png').readAsBytesSync(),
  );
  if (source == null || source.width != source.height || source.width < 1024) {
    throw StateError(
      'Canonical square app icon of at least 1024px is required.',
    );
  }
  // App Store icons must be opaque. Composite existing artwork over white;
  // preserve its design rather than adding another mask or rounding corners.
  final opaque = image.Image(
    width: source.width,
    height: source.height,
    numChannels: 3,
  );
  image.fill(opaque, color: image.ColorRgb8(255, 255, 255));
  image.compositeImage(opaque, source);
  const directory = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
  final catalog =
      jsonDecode(File('$directory/Contents.json').readAsStringSync())
          as Map<String, dynamic>;
  for (final entry in catalog['images'] as List<dynamic>) {
    final item = entry as Map<String, dynamic>;
    final filename = item['filename'] as String;
    if (!RegExp(r'^Icon-App-[0-9.@x]+\.png$').hasMatch(filename)) {
      throw StateError('Unexpected icon catalog filename.');
    }
    final size = double.parse((item['size'] as String).split('x').first);
    final scale = double.parse((item['scale'] as String).replaceAll('x', ''));
    final pixels = (size * scale).round();
    final resized = image.copyResize(
      opaque,
      width: pixels,
      height: pixels,
      interpolation: image.Interpolation.average,
    );
    File('$directory/$filename').writeAsBytesSync(image.encodePng(resized));
  }
}

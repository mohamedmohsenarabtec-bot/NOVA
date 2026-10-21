// Reproduce all original branding: flutter test tool/generate_brand.dart
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova/shared/brand.dart';

Future<void> png(String path, int size, {bool splash = false}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawColor(const Color(0xFFF8F6FF), BlendMode.src);
  final inset = size * (splash ? .1 : .18);
  canvas.translate(inset, inset);
  const NovaMark(
    ink: Color(0xFF6554C0),
    accent: Color(0xFFB74C40),
  ).paint(canvas, Size.square(size - inset * 2));
  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(path)..parent.createSync(recursive: true);
  file.writeAsBytesSync(data!.buffer.asUint8List());
  image.dispose();
  picture.dispose();
}

void main() {
  test('reproduce NOVA assets from shared vector geometry', () async {
    for (final variant in ['light', 'dark', 'mono']) {
      final ink = variant == 'dark'
          ? '#C2B5FF'
          : variant == 'mono'
          ? '#111111'
          : '#6554C0';
      final accent = variant == 'mono'
          ? ink
          : variant == 'dark'
          ? '#FFA18E'
          : '#B74C40';
      final paths =
          '<g fill="none" stroke="$ink" stroke-width="11" stroke-linecap="round" stroke-linejoin="round"><path d="${NovaMark.leftPath}"/><path d="${NovaMark.rightPath}"/></g><path fill="$accent" d="${NovaMark.sparkPath}"/>';
      for (final symbol in [true, false]) {
        final svg =
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${symbol ? 100 : 320} 100" role="img" aria-label="NOVA">$paths${symbol ? '' : '<text x="110" y="68" fill="$ink" font-family="sans-serif" font-size="56" font-weight="700" letter-spacing="6">NOVA</text>'}</svg>\n';
        final file = File(
          'assets/brand/${symbol ? 'symbol' : 'logo'}-$variant.svg',
        )..parent.createSync(recursive: true);
        file.writeAsStringSync(svg);
      }
    }
    await png('web/favicon.png', 48);
    for (final size in [192, 512]) {
      await png('web/icons/Icon-$size.png', size);
      await png('web/icons/Icon-maskable-$size.png', size);
    }
    for (final entry in {
      'mdpi': 48,
      'hdpi': 72,
      'xhdpi': 96,
      'xxhdpi': 144,
      'xxxhdpi': 192,
    }.entries) {
      await png(
        'android/app/src/main/res/mipmap-${entry.key}/ic_launcher.png',
        entry.value,
      );
    }
    final contents = jsonDecode(
      File('ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json')
          .readAsStringSync(),
    ) as Map;
    for (final entry in contents['images'] as List) {
      final size = double.parse((entry['size'] as String).split('x').first);
      final scale = double.parse(
        (entry['scale'] as String).replaceAll('x', ''),
      );
      await png(
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/${entry['filename']}',
        (size * scale).round(),
      );
    }
    for (var scale = 1; scale <= 3; scale++) {
      await png(
        'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage${scale == 1 ? '' : '@${scale}x'}.png',
        120 * scale,
        splash: true,
      );
    }
    await png(
      'android/app/src/main/res/drawable/nova_splash.png',
      144,
      splash: true,
    );
    await png('assets/brand/icon-1024.png', 1024);
    final vector =
        '<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="108dp" android:height="108dp" android:viewportWidth="100" android:viewportHeight="100"><group android:scaleX="0.7" android:scaleY="0.7" android:translateX="15" android:translateY="15"><path android:strokeColor="#6554C0" android:strokeWidth="11" android:strokeLineCap="round" android:strokeLineJoin="round" android:pathData="${NovaMark.leftPath}"/><path android:strokeColor="#6554C0" android:strokeWidth="11" android:strokeLineCap="round" android:pathData="${NovaMark.rightPath}"/><path android:fillColor="#B74C40" android:pathData="${NovaMark.sparkPath}"/></group></vector>';
    File('android/app/src/main/res/drawable/nova_foreground.xml')
        .writeAsStringSync(vector);
    File(
      'android/app/src/main/res/drawable/nova_monochrome.xml',
    ).writeAsStringSync(
      vector.replaceAll('#6554C0', '#FFFFFF').replaceAll('#B74C40', '#FFFFFF'),
    );
    Directory('android/app/src/main/res/mipmap-anydpi-v26')
        .createSync(recursive: true);
    File('android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml')
        .writeAsStringSync(
          '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android"><background android:drawable="@color/nova_icon_background"/><foreground android:drawable="@drawable/nova_foreground"/></adaptive-icon>',
        );
    Directory('android/app/src/main/res/mipmap-anydpi-v33')
        .createSync(recursive: true);
    File('android/app/src/main/res/mipmap-anydpi-v33/ic_launcher.xml')
        .writeAsStringSync(
          '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android"><background android:drawable="@color/nova_icon_background"/><foreground android:drawable="@drawable/nova_foreground"/><monochrome android:drawable="@drawable/nova_monochrome"/></adaptive-icon>',
        );
    File('android/app/src/main/res/values/nova_colors.xml').writeAsStringSync(
      '<resources><color name="nova_icon_background">#F8F6FF</color></resources>',
    );
  });
}

import 'dart:ui';
import '../models/choreography.dart';

/// Maps [VideoFilter] presets to [ColorFilter] matrices for real-time preview.
/// These approximate the ffmpeg filter strings — exact color grading happens
/// on export via ffmpeg.
ColorFilter? colorFilterFor(VideoFilter filter) {
  switch (filter) {
    case VideoFilter.none:
      return null;

    case VideoFilter.sunny:
      // brightness +0.1, saturation +1.3
      return const ColorFilter.matrix(<double>[
        1.3, 0.0, 0.0, 0.0, 25.5, //
        0.0, 1.3, 0.0, 0.0, 25.5, //
        0.0, 0.0, 1.3, 0.0, 25.5, //
        0.0, 0.0, 0.0, 1.0, 0.0, //
      ]);

    case VideoFilter.cool:
      // blue shift
      return const ColorFilter.matrix(<double>[
        0.9, 0.0, 0.0, 0.0, 0.0, //
        0.0, 0.95, 0.0, 0.0, 0.0, //
        0.0, 0.0, 1.2, 0.0, 30.0, //
        0.0, 0.0, 0.0, 1.0, 0.0, //
      ]);

    case VideoFilter.warm:
      // red/green shift
      return const ColorFilter.matrix(<double>[
        1.2, 0.0, 0.0, 0.0, 20.0, //
        0.0, 1.1, 0.0, 0.0, 10.0, //
        0.0, 0.0, 0.9, 0.0, 0.0, //
        0.0, 0.0, 0.0, 1.0, 0.0, //
      ]);

    case VideoFilter.vintage:
      // desaturated warm tone
      return const ColorFilter.matrix(<double>[
        0.6, 0.3, 0.1, 0.0, 20.0, //
        0.2, 0.6, 0.2, 0.0, 10.0, //
        0.1, 0.2, 0.5, 0.0, 0.0, //
        0.0, 0.0, 0.0, 1.0, 0.0, //
      ]);

    case VideoFilter.dramatic:
      // high contrast, slight desaturation
      return const ColorFilter.matrix(<double>[
        1.4, -0.1, -0.1, 0.0, -15.0, //
        -0.1, 1.4, -0.1, 0.0, -15.0, //
        -0.1, -0.1, 1.4, 0.0, -15.0, //
        0.0, 0.0, 0.0, 1.0, 0.0, //
      ]);

    case VideoFilter.blackWhite:
      // luminance-based grayscale
      return const ColorFilter.matrix(<double>[
        0.2126, 0.7152, 0.0722, 0.0, 0.0, //
        0.2126, 0.7152, 0.0722, 0.0, 0.0, //
        0.2126, 0.7152, 0.0722, 0.0, 0.0, //
        0.0, 0.0, 0.0, 1.0, 0.0, //
      ]);

    case VideoFilter.spooky:
      // dark, desaturated, slight green tint
      return const ColorFilter.matrix(<double>[
        0.5, 0.1, 0.0, 0.0, -20.0, //
        0.1, 0.6, 0.1, 0.0, -10.0, //
        0.0, 0.1, 0.5, 0.0, -20.0, //
        0.0, 0.0, 0.0, 1.0, 0.0, //
      ]);
  }
}

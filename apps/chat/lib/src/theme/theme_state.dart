import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';

enum MessageBubbleStyle { modern, compact, brutalist }

class WallpaperConfig {
  const WallpaperConfig({
    this.imagePath,
    this.blur = 0.0,
    this.brightness = 1.0,
    this.opacity = 1.0,
  });

  final String? imagePath;
  final double blur;
  final double brightness;
  final double opacity;

  WallpaperConfig copyWith({
    String? imagePath,
    double? blur,
    double? brightness,
    double? opacity,
    bool clearImage = false,
  }) =>
      WallpaperConfig(
        imagePath: clearImage ? null : (imagePath ?? this.imagePath),
        blur: blur ?? this.blur,
        brightness: brightness ?? this.brightness,
        opacity: opacity ?? this.opacity,
      );
}

class MercuryThemeState {
  const MercuryThemeState({
    this.accentColor = const Color(0xFF7C6CF2),
    this.surfaceColor = const Color(0xFF1B1E26),
    this.sidebarColor = const Color(0xFF15171E),
    this.railColor = const Color(0xFF0E1015),
    this.bubbleStyle = MessageBubbleStyle.modern,
    this.typographyScale = 1.0,
    this.glassmorphismBlur = 12.0,
    this.wallpaper = const WallpaperConfig(),
  });

  final Color accentColor;
  final Color surfaceColor;
  final Color sidebarColor;
  final Color railColor;
  final MessageBubbleStyle bubbleStyle;
  final double typographyScale;
  final double glassmorphismBlur;
  final WallpaperConfig wallpaper;

  MercuryThemeState copyWith({
    Color? accentColor,
    Color? surfaceColor,
    Color? sidebarColor,
    Color? railColor,
    MessageBubbleStyle? bubbleStyle,
    double? typographyScale,
    double? glassmorphismBlur,
    WallpaperConfig? wallpaper,
  }) =>
      MercuryThemeState(
        accentColor: accentColor ?? this.accentColor,
        surfaceColor: surfaceColor ?? this.surfaceColor,
        sidebarColor: sidebarColor ?? this.sidebarColor,
        railColor: railColor ?? this.railColor,
        bubbleStyle: bubbleStyle ?? this.bubbleStyle,
        typographyScale: typographyScale ?? this.typographyScale,
        glassmorphismBlur: glassmorphismBlur ?? this.glassmorphismBlur,
        wallpaper: wallpaper ?? this.wallpaper,
      );
}

class MercuryThemeNotifier extends Notifier<MercuryThemeState> {
  @override
  MercuryThemeState build() {
    _loadFromStorage();
    return const MercuryThemeState();
  }

  Future<void> _loadFromStorage() async {
    final repo = ref.read(localStorageRepositoryProvider);
    final saved = await repo.loadTheme();
    if (saved != null) {
      state = saved;
    }
  }

  void _persist() {
    ref.read(localStorageRepositoryProvider).saveTheme(state);
  }

  void setAccentColor(Color color) {
    state = state.copyWith(accentColor: color);
    _persist();
  }

  void setSurfaceColor(Color color) {
    state = state.copyWith(surfaceColor: color);
    _persist();
  }

  void setBubbleStyle(MessageBubbleStyle style) {
    state = state.copyWith(bubbleStyle: style);
    _persist();
  }

  void setTypographyScale(double scale) {
    state = state.copyWith(typographyScale: scale);
    _persist();
  }

  void setGlassmorphismBlur(double blur) {
    state = state.copyWith(glassmorphismBlur: blur);
    _persist();
  }

  void updateWallpaper(WallpaperConfig Function(WallpaperConfig) update) {
    state = state.copyWith(wallpaper: update(state.wallpaper));
    _persist();
  }

  void resetToDefaults() {
    state = const MercuryThemeState();
    _persist();
  }
}

final themeStateProvider =
    NotifierProvider<MercuryThemeNotifier, MercuryThemeState>(
  MercuryThemeNotifier.new,
);

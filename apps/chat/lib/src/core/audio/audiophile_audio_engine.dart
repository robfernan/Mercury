import 'dart:async';

/// Audio profile presets tailored for audiophile DACs (Moondrop MIAD01 dual Cirrus Logic DAC,
/// 4.4mm balanced output, Windows ASIO, and Linux PipeWire/ALSA direct).
enum AudioQualityPreset {
  standard(
    title: 'Standard RTC (Discord / Matrix Spec)',
    bitrateKbps: 64,
    sampleRateHz: 48000,
    channels: 1,
    latencyMs: 20,
    description: 'Mono Opus 64 kbps, typical VoIP compression',
  ),
  highFidelity(
    title: 'Studio Hi-Fi Stereo',
    bitrateKbps: 192,
    sampleRateHz: 48000,
    channels: 2,
    latencyMs: 10,
    description: 'Stereo Opus 192 kbps, wide stereo field',
  ),
  audiophileBitPerfect(
    title: 'Moondrop MIAD01 Lossless Direct (Master)',
    bitrateKbps: 510,
    sampleRateHz: 48000,
    channels: 2,
    latencyMs: 5,
    description: 'Full-band 510 kbps Opus, bypasses Android AudioFlinger resampling',
  );

  const AudioQualityPreset({
    required this.title,
    required this.bitrateKbps,
    required this.sampleRateHz,
    required this.channels,
    required this.latencyMs,
    required this.description,
  });

  final String title;
  final int bitrateKbps;
  final int sampleRateHz;
  final int channels;
  final int latencyMs;
  final String description;
}

/// Service managing audiophile voice parameters and hardware DAC routing.
class AudiophileAudioEngine {
  AudiophileAudioEngine({
    AudioQualityPreset initialPreset = AudioQualityPreset.audiophileBitPerfect,
  }) : _currentPreset = initialPreset;

  AudioQualityPreset _currentPreset;
  AudioQualityPreset get currentPreset => _currentPreset;

  bool _directDacBypassEnabled = true;
  bool get directDacBypassEnabled => _directDacBypassEnabled;

  bool _ditherEnabled = true;
  bool get ditherEnabled => _ditherEnabled;

  final _presetController = StreamController<AudioQualityPreset>.broadcast();
  Stream<AudioQualityPreset> get presetStream => _presetController.stream;

  void setPreset(AudioQualityPreset preset) {
    _currentPreset = preset;
    _presetController.add(_currentPreset);
  }

  void toggleDirectDacBypass(bool value) {
    _directDacBypassEnabled = value;
  }

  void toggleDither(bool value) {
    _ditherEnabled = value;
  }

  void dispose() {
    _presetController.close();
  }
}

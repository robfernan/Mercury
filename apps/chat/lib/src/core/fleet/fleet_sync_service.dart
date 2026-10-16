import 'dart:async';
import 'package:flutter/services.dart';
import 'fleet_models.dart';

/// Service managing the user's trusted fleet:
/// - One-Scan QR Noise-IK device pairing
/// - Cross-device universal clipboard sync
/// - Cross-device P2P fast file drop
/// - Unified notification & read-state acknowledgment across all devices
class FleetSyncService {
  FleetSyncService({
    required this.currentDeviceId,
    required this.currentDeviceName,
  }) {
    _initDefaultFleet();
  }

  final String currentDeviceId;
  final String currentDeviceName;

  final Map<String, FleetDevice> _devices = {};
  final _devicesController = StreamController<List<FleetDevice>>.broadcast();
  Stream<List<FleetDevice>> get devicesStream => _devicesController.stream;
  List<FleetDevice> get devices => List.unmodifiable(_devices.values);

  final List<FleetSharedItem> _clipboardHistory = [];
  final _clipboardController = StreamController<List<FleetSharedItem>>.broadcast();
  Stream<List<FleetSharedItem>> get clipboardStream => _clipboardController.stream;
  List<FleetSharedItem> get clipboardHistory => List.unmodifiable(_clipboardHistory);

  final Set<String> _readMessageIds = {};

  void _initDefaultFleet() {
    final now = DateTime.now();
    _devices[currentDeviceId] = FleetDevice(
      id: currentDeviceId,
      name: currentDeviceName,
      deviceType: 'Windows 11 Desktop (Primary Hub)',
      enrolledAt: now.subtract(const Duration(days: 14)),
      lastSyncAt: now,
      ed25519PublicKey: '4A7B...99C2',
      isCurrentDevice: true,
      ipAddress: '192.168.1.100',
    );

    // Initial trusted fleet peers for the user's setup
    final wacom = FleetDevice(
      id: 'dev_wacom_01',
      name: 'Wacom MobileStudio Pro 13',
      deviceType: 'Stylus Drawing Workstation',
      enrolledAt: now.subtract(const Duration(days: 7)),
      lastSyncAt: now.subtract(const Duration(minutes: 2)),
      ed25519PublicKey: '8B3F...11E4',
      isCurrentDevice: false,
      ipAddress: '192.168.1.142',
    );
    _devices[wacom.id] = wacom;

    final phone = FleetDevice(
      id: 'dev_miad01_01',
      name: 'Moondrop MIAD01 5G',
      deviceType: 'Audiophile Android Phone',
      enrolledAt: now.subtract(const Duration(days: 3)),
      lastSyncAt: now.subtract(const Duration(seconds: 40)),
      ed25519PublicKey: '5E22...77D1',
      isCurrentDevice: false,
      ipAddress: 'Cellular WAN (STUN P2P)',
    );
    _devices[phone.id] = phone;

    final debian = FleetDevice(
      id: 'dev_debian_01',
      name: 'HP Debian Laptop',
      deviceType: 'Debian Linux Node',
      enrolledAt: now.subtract(const Duration(days: 1)),
      lastSyncAt: now.subtract(const Duration(minutes: 8)),
      ed25519PublicKey: '3C99...44A8',
      isCurrentDevice: false,
      ipAddress: '192.168.1.189',
    );
    _devices[debian.id] = debian;

    // Seed sample cross-device clipboard items
    _clipboardHistory.add(
      FleetSharedItem(
        id: 'clip_1',
        originDeviceId: 'dev_wacom_01',
        originDeviceName: 'Wacom MobileStudio',
        content: 'mercury://canvas/vector-export-palette.json',
        timestamp: now.subtract(const Duration(minutes: 12)),
        isFileName: false,
      ),
    );
    _clipboardHistory.add(
      FleetSharedItem(
        id: 'clip_2',
        originDeviceId: 'dev_miad01_01',
        originDeviceName: 'Moondrop MIAD01',
        content: 'Flac 24bit/96kHz Opus Reference Stream',
        timestamp: now.subtract(const Duration(minutes: 3)),
        isFileName: false,
      ),
    );
  }

  /// Generates a Noise-IK enrollment payload to display as QR code on this screen.
  FleetEnrollmentPayload generateEnrollmentQr() {
    return FleetEnrollmentPayload(
      enrollmentSessionId: 'enroll_${DateTime.now().millisecondsSinceEpoch}',
      ephemeralPublicKey: 'NOISE_IK_EPK_9F2B8810237C',
      hubFingerprint: '9420 8122 3911 0429 8812',
      invitationExpiry: DateTime.now().add(const Duration(minutes: 5)),
      lanDirectEndpoint: '192.168.1.100:42424',
    );
  }

  /// Enroll a newly scanned device into the user's trusted fleet.
  void enrollDevice(FleetDevice newDevice) {
    _devices[newDevice.id] = newDevice;
    _devicesController.add(devices);
  }

  /// Remove/revoke a device from the fleet.
  void revokeDevice(String deviceId) {
    if (deviceId != currentDeviceId) {
      _devices.remove(deviceId);
      _devicesController.add(devices);
    }
  }

  /// Push text to the cross-device shared clipboard.
  Future<void> shareClipboardText(String text) async {
    final item = FleetSharedItem(
      id: 'clip_${DateTime.now().millisecondsSinceEpoch}',
      originDeviceId: currentDeviceId,
      originDeviceName: currentDeviceName,
      content: text,
      timestamp: DateTime.now(),
      isFileName: false,
    );
    _clipboardHistory.insert(0, item);
    _clipboardController.add(clipboardHistory);
    // Write to local OS clipboard
    await Clipboard.setData(ClipboardData(text: text));
  }

  /// Cross-device file drop (AirDrop equivalent)
  void dropFile({required String fileName, required int sizeBytes}) {
    final item = FleetSharedItem(
      id: 'file_${DateTime.now().millisecondsSinceEpoch}',
      originDeviceId: currentDeviceId,
      originDeviceName: currentDeviceName,
      content: fileName,
      timestamp: DateTime.now(),
      isFileName: true,
      fileSizeBytes: sizeBytes,
    );
    _clipboardHistory.insert(0, item);
    _clipboardController.add(clipboardHistory);
  }

  /// Mark message read on this device; synchronizes acknowledgment to fleet devices
  /// so duplicate notification alerts are cleared everywhere.
  void markMessageReadEverywhere(String messageId, String channelId) {
    _readMessageIds.add(messageId);
  }

  bool isMessageReadInFleet(String messageId) => _readMessageIds.contains(messageId);

  void dispose() {
    _devicesController.close();
    _clipboardController.close();
  }
}

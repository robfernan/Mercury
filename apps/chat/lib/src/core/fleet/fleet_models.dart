import 'dart:convert';

/// Represents a trusted hardware device in the user's personal fleet.
class FleetDevice {
  const FleetDevice({
    required this.id,
    required this.name,
    required this.deviceType,
    required this.enrolledAt,
    required this.lastSyncAt,
    required this.ed25519PublicKey,
    required this.isCurrentDevice,
    this.ipAddress,
  });

  final String id;
  final String name;
  final String deviceType; // e.g. 'Windows 11 Desktop', 'Wacom Studio Pro 13', 'Moondrop MIAD01', 'HP Debian'
  final DateTime enrolledAt;
  final DateTime lastSyncAt;
  final String ed25519PublicKey;
  final bool isCurrentDevice;
  final String? ipAddress;

  FleetDevice copyWith({
    String? id,
    String? name,
    String? deviceType,
    DateTime? enrolledAt,
    DateTime? lastSyncAt,
    String? ed25519PublicKey,
    bool? isCurrentDevice,
    String? ipAddress,
  }) {
    return FleetDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      deviceType: deviceType ?? this.deviceType,
      enrolledAt: enrolledAt ?? this.enrolledAt,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      ed25519PublicKey: ed25519PublicKey ?? this.ed25519PublicKey,
      isCurrentDevice: isCurrentDevice ?? this.isCurrentDevice,
      ipAddress: ipAddress ?? this.ipAddress,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'deviceType': deviceType,
        'enrolledAt': enrolledAt.toIso8601String(),
        'lastSyncAt': lastSyncAt.toIso8601String(),
        'ed25519PublicKey': ed25519PublicKey,
        'isCurrentDevice': isCurrentDevice,
        'ipAddress': ipAddress,
      };

  factory FleetDevice.fromJson(Map<String, dynamic> json) {
    return FleetDevice(
      id: json['id'] as String,
      name: json['name'] as String,
      deviceType: json['deviceType'] as String,
      enrolledAt: DateTime.parse(json['enrolledAt'] as String),
      lastSyncAt: DateTime.parse(json['lastSyncAt'] as String),
      ed25519PublicKey: json['ed25519PublicKey'] as String,
      isCurrentDevice: json['isCurrentDevice'] as bool? ?? false,
      ipAddress: json['ipAddress'] as String?,
    );
  }
}

/// QR Enrollment payload for Noise-IK cross-signing handshake.
class FleetEnrollmentPayload {
  const FleetEnrollmentPayload({
    required this.enrollmentSessionId,
    required this.ephemeralPublicKey,
    required this.hubFingerprint,
    required this.invitationExpiry,
    required this.lanDirectEndpoint,
  });

  final String enrollmentSessionId;
  final String ephemeralPublicKey;
  final String hubFingerprint;
  final DateTime invitationExpiry;
  final String lanDirectEndpoint;

  String toQrString() {
    return jsonEncode({
      'protocol': 'MERCURY_NOISE_IK_V1',
      'sid': enrollmentSessionId,
      'epk': ephemeralPublicKey,
      'fp': hubFingerprint,
      'exp': invitationExpiry.millisecondsSinceEpoch,
      'lan': lanDirectEndpoint,
    });
  }
}

/// Item shared across the user's fleet (Universal clipboard & P2P AirDrop equivalent)
class FleetSharedItem {
  const FleetSharedItem({
    required this.id,
    required this.originDeviceId,
    required this.originDeviceName,
    required this.content,
    required this.timestamp,
    this.isFileName,
    this.fileSizeBytes,
  });

  final String id;
  final String originDeviceId;
  final String originDeviceName;
  final String content; // Text snippet, URL, or file name
  final DateTime timestamp;
  final bool? isFileName;
  final int? fileSizeBytes;
}

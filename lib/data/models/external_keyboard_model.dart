/// 外置键盘设备模型
class ExternalKeyboardDevice {
  final String deviceId;
  final String deviceName;
  final String vendorId;
  final String productId;
  final bool isConnected;
  final DateTime? connectedAt;

  ExternalKeyboardDevice({
    required this.deviceId,
    required this.deviceName,
    required this.vendorId,
    required this.productId,
    required this.isConnected,
    this.connectedAt,
  });

  factory ExternalKeyboardDevice.fromJson(Map<String, dynamic> json) {
    return ExternalKeyboardDevice(
      deviceId: json['deviceId'] ?? '',
      deviceName: json['deviceName'] ?? '未知设备',
      vendorId: json['vendorId'] ?? '',
      productId: json['productId'] ?? '',
      isConnected: json['isConnected'] ?? false,
      connectedAt: json['connectedAt'] != null
          ? DateTime.parse(json['connectedAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'deviceName': deviceName,
      'vendorId': vendorId,
      'productId': productId,
      'isConnected': isConnected,
      'connectedAt': connectedAt?.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'ExternalKeyboardDevice(deviceId: $deviceId, deviceName: $deviceName, '
        'vendorId: $vendorId, productId: $productId, isConnected: $isConnected)';
  }
}

/// 外置键盘状态枚举
enum ExternalKeyboardStatus {
  notConnected, // 未连接
  connected, // 已连接
  testing, // 测试中
  authorized, // 已授权
  error, // 错误状态
}

extension ExternalKeyboardStatusExtension on ExternalKeyboardStatus {
  String get displayName {
    switch (this) {
      case ExternalKeyboardStatus.notConnected:
        return '未连接';
      case ExternalKeyboardStatus.connected:
        return '已连接';
      case ExternalKeyboardStatus.testing:
        return '测试中';
      case ExternalKeyboardStatus.authorized:
        return '已授权';
      case ExternalKeyboardStatus.error:
        return '错误';
    }
  }
}

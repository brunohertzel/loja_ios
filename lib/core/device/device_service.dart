import 'dart:math';

import 'package:package_info_plus/package_info_plus.dart';

import '../storage/secure_session_store.dart';

class DeviceService {
  DeviceService(this.store);

  final SecureSessionStore store;

  String deviceId = '';
  String appVersion = '';
  String appBuild = '';
  String packageName = '';

  Future<void> initialize() async {
    deviceId = (await store.deviceId)?.trim() ?? '';
    if (deviceId.isEmpty) {
      deviceId = _newDeviceId();
      await store.setDeviceId(deviceId);
    }

    final info = await PackageInfo.fromPlatform();
    appVersion = info.version;
    appBuild = info.buildNumber;
    packageName = info.packageName;
  }

  String get shortDeviceId =>
      deviceId.length <= 12 ? deviceId : deviceId.substring(0, 12);

  String _newDeviceId() {
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}

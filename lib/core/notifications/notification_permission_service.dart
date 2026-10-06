import 'package:flutter/services.dart';

class NotificationPermissionService {
  static const channel =
      MethodChannel('br.com.softsistemas.mobile/notifications');
  static bool allowed(String status) =>
      status == 'granted' || status == 'provisional';

  Future<String> status() => _status('status');
  Future<String> request() => _status('request');
  Future<String> _status(String method) async {
    try {
      final value = await channel.invokeMethod<String>(method);
      return const {
        'granted',
        'provisional',
        'denied',
        'blocked',
        'not_determined'
      }.contains(value)
          ? value!
          : 'unavailable';
    } on PlatformException {
      return 'unavailable';
    } on MissingPluginException {
      return 'unavailable';
    }
  }

  Future<bool> openSettings() async {
    try {
      return await channel.invokeMethod<bool>('openSettings') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

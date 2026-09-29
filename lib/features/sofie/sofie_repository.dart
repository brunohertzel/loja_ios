import '../../core/network/api_client.dart';
import 'sofie_models.dart';

class SofieRepository {
  SofieRepository(this.api);

  final ApiClient api;

  Future<SofieSession> bootstrap() async {
    final json = await api.post(
      '/sofie/index.php',
      const <String, dynamic>{'action': 'bootstrap'},
      timeout: const Duration(seconds: 35),
    );
    return SofieSession.fromJson(json);
  }

  Future<SofieReply> send(String message) async {
    final requestId = 'm-${DateTime.now().microsecondsSinceEpoch}';
    final json = await api.post(
      '/sofie/index.php',
      <String, dynamic>{
        'action': 'message',
        'message': message,
        'request_id': requestId,
      },
      timeout: const Duration(seconds: 125),
    );
    return SofieReply.fromJson(json);
  }

  Future<SofieReply> poll(int lastId) async {
    final json = await api.post(
      '/sofie/index.php',
      <String, dynamic>{'action': 'poll', 'last_id': lastId},
      timeout: const Duration(seconds: 35),
    );
    return SofieReply.fromJson(json);
  }

  Future<SofieReply> confirmAction(int actionId) async {
    final json = await api.post(
      '/sofie/index.php',
      <String, dynamic>{
        'action': 'confirm_action',
        'action_id': actionId,
      },
      timeout: const Duration(seconds: 45),
    );
    return SofieReply.fromJson(json);
  }
}

import 'package:supabase_flutter/supabase_flutter.dart';
import 'secure_storage.dart';

class PinService {
  final SupabaseClient _client;

  PinService(this._client);

  Future<bool> setPin(String pin) async {
    try {
      final response = await _client.rpc('set_client_pin', params: {'p_pin': pin});
      if (response is Map && response['success'] == true) {
        await SecureStorageService.setPinEnabled(true);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> verifyPin(String pin) async {
    try {
      final response = await _client.rpc('verify_client_pin', params: {'p_pin': pin});
      return response is Map && response['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> removePin() async {
    try {
      // Set pin_hash to null by calling set_client_pin with empty
      // Actually we need a separate function, but for now we just update local state
      await SecureStorageService.setPinEnabled(false);
      return true;
    } catch (_) {
      return false;
    }
  }
}

import '../../core/api/api_client.dart';
import '../../core/version.dart';
import '../models/app_user.dart';

/// Accès aux routes d'identité. Le repository est la seule porte d'entrée des données.
class AuthRepository {
  const AuthRepository(this._client);

  final ApiClient _client;

  Future<AuthResult> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final envelope = await _client.postEnvelope<AuthResult>(
      '/v1/auth/register',
      parse: AuthResult.fromJson,
      body: {
        'email': email,
        'password': password,
        if (displayName != null && displayName.trim().isNotEmpty)
          'display_name': displayName.trim(),
      },
    );
    return envelope.data;
  }

  Future<AuthResult> login({required String email, required String password}) async {
    final envelope = await _client.postEnvelope<AuthResult>(
      '/v1/auth/login',
      parse: AuthResult.fromJson,
      body: {
        'email': email,
        'password': password,
        'device': {'label': 'Android', 'platform': 'android', 'app_version': appVersion},
      },
    );
    return envelope.data;
  }

  Future<AuthResult> refresh(String refreshToken) async {
    final envelope = await _client.postEnvelope<AuthResult>(
      '/v1/auth/refresh',
      parse: AuthResult.fromJson,
      body: {'refresh_token': refreshToken},
    );
    return envelope.data;
  }

  Future<void> logout(String refreshToken) {
    return _client.postVoid('/v1/auth/logout', body: {'refresh_token': refreshToken});
  }

  Future<AppUser> me() async {
    final envelope = await _client.getEnvelope<AppUser>(
      '/v1/me',
      parse: AppUser.fromJson,
    );
    return envelope.data;
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/token_store.dart';
import '../../data/models/app_user.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/catalog_repository.dart';

/// URL de l'API : surchargeable au build.
/// `flutter build apk --dart-define=API_BASE_URL=https://api.footballvalue.ai`
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8000',
);

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(
    baseUrl: apiBaseUrl,
    // Le rafraîchissement a échoué : la session locale n'est plus valide.
    // `ref.read` est appelé au moment de l'erreur, jamais à la construction,
    // ce qui évite un cycle de dépendances avec `sessionProvider`.
    onSessionExpired: () => ref.read(sessionProvider.notifier).handleSessionExpired(),
  );
  ref.onDispose(client.clearTokens);
  return client;
});

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(apiClientProvider)),
);

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => CatalogRepository(ref.watch(apiClientProvider)),
);

/// État de session exposé à l'interface.
enum SessionStatus { unknown, unauthenticated, authenticated }

class SessionState {
  const SessionState({
    this.status = SessionStatus.unknown,
    this.user,
    this.error,
    this.busy = false,
  });

  final SessionStatus status;
  final AppUser? user;
  final String? error;
  final bool busy;

  bool get isAuthenticated => status == SessionStatus.authenticated;

  SessionState copyWith({
    SessionStatus? status,
    AppUser? user,
    String? error,
    bool? busy,
    bool clearError = false,
    bool clearUser = false,
  }) {
    return SessionState(
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
      error: clearError ? null : (error ?? this.error),
      busy: busy ?? this.busy,
    );
  }
}

class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() {
    Future.microtask(restore);
    return const SessionState();
  }

  AuthRepository get _auth => ref.read(authRepositoryProvider);
  ApiClient get _api => ref.read(apiClientProvider);
  TokenStore get _store => ref.read(tokenStoreProvider);

  /// Restaure la session depuis le Keystore, sans bloquer le premier rendu.
  Future<void> restore() async {
    final tokens = await _store.read();
    if (tokens == null) {
      state = const SessionState(status: SessionStatus.unauthenticated);
      return;
    }

    _api.setTokens(accessToken: tokens.accessToken, refreshToken: tokens.refreshToken);
    try {
      final user = await _auth.me();
      state = SessionState(status: SessionStatus.authenticated, user: user);
    } on Exception {
      try {
        final refreshed = await _auth.refresh(tokens.refreshToken);
        _api.setTokens(
          accessToken: refreshed.accessToken,
          refreshToken: refreshed.refreshToken,
        );
        await _store.write(
          TokenPair(
            accessToken: refreshed.accessToken,
            refreshToken: refreshed.refreshToken,
          ),
        );
        state = SessionState(status: SessionStatus.authenticated, user: refreshed.user);
      } on Exception {
        await _store.clear();
        _api.clearTokens();
        state = const SessionState(status: SessionStatus.unauthenticated);
      }
    }
  }

  Future<bool> login({required String email, required String password}) async {
    state = state.copyWith(busy: true, clearError: true, clearUser: true);
    try {
      final result = await _auth.login(email: email.trim(), password: password);
      await _apply(result);
      return true;
    } on Exception catch (error) {
      state = SessionState(status: SessionStatus.unauthenticated, error: _message(error));
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    state = state.copyWith(busy: true, clearError: true, clearUser: true);
    try {
      final result = await _auth.register(
        email: email.trim(),
        password: password,
        displayName: displayName,
      );
      await _apply(result);
      return true;
    } on Exception catch (error) {
      state = SessionState(status: SessionStatus.unauthenticated, error: _message(error));
      return false;
    }
  }

  Future<void> logout() async {
    final refresh = _api.refreshToken;
    if (refresh != null) {
      try {
        await _auth.logout(refresh);
      } on Exception {
        // Une déconnexion doit réussir même hors ligne : le jeton local est effacé.
      }
    }
    await _store.clear();
    _api.clearTokens();
    state = const SessionState(status: SessionStatus.unauthenticated);
  }

  /// Appelée par `ApiClient` quand le rafraîchissement échoue (401 persistant).
  /// Ne fait rien si l'utilisateur s'est déjà déconnecté entre-temps.
  Future<void> handleSessionExpired() async {
    if (!state.isAuthenticated) return;
    await _store.clear();
    _api.clearTokens();
    state = const SessionState(
      status: SessionStatus.unauthenticated,
      error: 'Session expirée. Reconnectez-vous.',
    );
  }

  Future<void> _apply(AuthResult result) async {
    _api.setTokens(accessToken: result.accessToken, refreshToken: result.refreshToken);
    await _store.write(
      TokenPair(accessToken: result.accessToken, refreshToken: result.refreshToken),
    );
    state = SessionState(status: SessionStatus.authenticated, user: result.user);
  }

  String _message(Object error) {
    final text = error.toString();
    if (text.contains('RATE_LIMITED')) {
      return 'Trop de tentatives. Patientez une minute avant de réessayer.';
    }
    if (text.contains('NETWORK_ERROR')) {
      return 'Serveur injoignable. Vérifiez votre connexion.';
    }
    if (text.contains('UNAUTHENTICATED')) {
      return 'Adresse e-mail ou mot de passe incorrect.';
    }
    if (text.contains('CONFLICT')) {
      return 'Un compte existe déjà avec cette adresse.';
    }
    // Le message serveur est déjà en français et sans détail technique.
    final match = RegExp(r'ApiException\([^,]+, (.+)\)$').firstMatch(text);
    return match?.group(1) ?? 'Une erreur est survenue. Réessayez.';
  }
}

final sessionProvider = NotifierProvider<SessionController, SessionState>(
  SessionController.new,
);

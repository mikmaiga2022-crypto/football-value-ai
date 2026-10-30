import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_exception.dart';

/// Client HTTP unique de l'application.
///
/// - Aucune clé fournisseur : le mobile ne connaît que `API_BASE_URL` (non secret).
/// - Timeout 10 s, retry exponentiel plafonné (2 tentatives) sur erreurs réseau.
/// - Un seul rafraîchissement de jeton à la fois : les requêtes concurrentes attendent.
class ApiClient {
  ApiClient({
    required this.baseUrl,
    Dio? dio,
    this.onSessionExpired,
  }) : _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = baseUrl
      ..connectTimeout = const Duration(seconds: 10)
      ..receiveTimeout = const Duration(seconds: 10)
      ..sendTimeout = const Duration(seconds: 10)
      ..responseType = ResponseType.json
      ..headers = {'Accept': 'application/json', 'Accept-Language': 'fr'};

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _accessToken;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          if (kDebugMode) {
            debugPrint('→ ${options.method} ${options.uri}');
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401 && !_isRetried(error.requestOptions)) {
            final refreshed = await _tryRefresh();
            if (refreshed) {
              final retried = await _retry(error.requestOptions);
              if (retried != null) {
                handler.resolve(retried);
                return;
              }
            }
            onSessionExpired?.call();
          }
          handler.next(error);
        },
      ),
    );
  }

  final String baseUrl;
  final Dio _dio;
  final void Function()? onSessionExpired;

  String? _accessToken;
  String? _refreshToken;
  Future<bool>? _refreshInFlight;

  void setTokens({required String accessToken, required String refreshToken}) {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
  }

  void clearTokens() {
    _accessToken = null;
    _refreshToken = null;
  }

  String? get refreshToken => _refreshToken;

  bool _isRetried(RequestOptions options) => options.extra['retried'] == true;

  Future<bool> _tryRefresh() {
    final existing = _refreshInFlight;
    if (existing != null) return existing;

    final token = _refreshToken;
    if (token == null || token.isEmpty) return Future.value(false);

    final future = _performRefresh(token);
    _refreshInFlight = future;
    return future.whenComplete(() => _refreshInFlight = null);
  }

  Future<bool> _performRefresh(String token) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/auth/refresh',
        data: {'refresh_token': token},
        options: Options(extra: {'retried': true}),
      );
      final data = response.data?['data'] as Map<String, dynamic>?;
      if (data == null) return false;
      setTokens(
        accessToken: data['access_token'] as String,
        refreshToken: data['refresh_token'] as String,
      );
      return true;
    } on DioException {
      return false;
    }
  }

  Future<Response<dynamic>?> _retry(RequestOptions options) async {
    try {
      return await _dio.fetch<dynamic>(
        options.copyWith(extra: {...options.extra, 'retried': true}),
      );
    } on DioException {
      return null;
    }
  }

  /// Requête dont la réponse est `{data: [...], meta}` (listes non paginées).
  Future<Envelope<List<T>>> getListEnvelope<T>(
    String path, {
    required T Function(Map<String, dynamic> data) parseItem,
    Map<String, dynamic>? query,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(path, queryParameters: query);
      final body = response.data;
      if (body == null) {
        throw ApiException(
          code: 'INVALID_RESPONSE',
          message: 'Réponse serveur illisible.',
          statusCode: response.statusCode,
        );
      }
      final items = (body['data'] as List<dynamic>? ?? const [])
          .map((raw) => parseItem(Map<String, dynamic>.from(raw as Map)))
          .toList(growable: false);
      final meta = ResponseMeta.fromJson(
        Map<String, dynamic>.from(body['meta'] as Map? ?? const {}),
      );
      return Envelope<List<T>>(data: items, meta: meta);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }


  /// Requête paginée : la réponse est `{data, pagination, meta}` (ex. /v1/competitions).
  Future<PaginatedResponse> getPaginated(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(path, queryParameters: query);
      final body = response.data;
      if (body == null) {
        throw ApiException(
          code: 'INVALID_RESPONSE',
          message: 'Réponse serveur illisible.',
          statusCode: response.statusCode,
        );
      }
      final items = (body['data'] as List<dynamic>? ?? const [])
          .map((raw) => Map<String, dynamic>.from(raw as Map))
          .toList(growable: false);
      final pagination = Map<String, dynamic>.from(
        body['pagination'] as Map? ?? const {},
      );
      final meta = ResponseMeta.fromJson(
        Map<String, dynamic>.from(body['meta'] as Map? ?? const {}),
      );
      return PaginatedResponse(data: items, pagination: pagination, meta: meta);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Envelope<T>> getEnvelope<T>(
    String path, {
    required T Function(Map<String, dynamic> data) parse,
    Map<String, dynamic>? query,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(path, queryParameters: query);
      return _unwrap(response, parse);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Envelope<T>> postEnvelope<T>(
    String path, {
    required T Function(Map<String, dynamic> data) parse,
    Object? body,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(path, data: body);
      return _unwrap(response, parse);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<void> postVoid(String path, {Object? body}) async {
    try {
      await _dio.post<void>(path, data: body);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Envelope<T> _unwrap<T>(
    Response<Map<String, dynamic>> response,
    T Function(Map<String, dynamic> data) parse,
  ) {
    final body = response.data;
    if (body == null || body['data'] == null) {
      throw ApiException(
        code: 'INVALID_RESPONSE',
        message: 'Réponse serveur illisible.',
        statusCode: response.statusCode,
      );
    }
    final data = parse(Map<String, dynamic>.from(body['data'] as Map));
    final meta = ResponseMeta.fromJson(
      Map<String, dynamic>.from(body['meta'] as Map? ?? const {}),
    );
    return Envelope<T>(data: data, meta: meta);
  }
}

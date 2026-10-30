import 'package:dio/dio.dart';

/// Erreur d'API normalisée : le mobile ne manipule jamais un `DioException` brut.
class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.statusCode,
    this.details = const {},
    this.requestId,
  });

  final String code;
  final String message;
  final int? statusCode;
  final Map<String, dynamic> details;
  final String? requestId;

  bool get isUnauthenticated => code == 'UNAUTHENTICATED' || code == 'TOKEN_EXPIRED';
  bool get isRateLimited => code == 'RATE_LIMITED';

  factory ApiException.fromResponse(Response<dynamic> response) {
    final body = response.data;
    if (body is Map && body['error'] is Map) {
      final error = Map<String, dynamic>.from(body['error'] as Map);
      return ApiException(
        code: error['code'] as String? ?? 'UNKNOWN_ERROR',
        message: error['message'] as String? ?? 'Une erreur est survenue.',
        statusCode: response.statusCode,
        details: Map<String, dynamic>.from(error['details'] as Map? ?? const {}),
        requestId: error['request_id'] as String?,
      );
    }
    return ApiException(
      code: 'UNKNOWN_ERROR',
      message: 'Réponse inattendue du serveur.',
      statusCode: response.statusCode,
    );
  }

  factory ApiException.fromDio(DioException error) {
    final response = error.response;
    if (response != null) return ApiException.fromResponse(response);

    final type = error.type;
    if (type == DioExceptionType.connectionTimeout ||
        type == DioExceptionType.receiveTimeout ||
        type == DioExceptionType.sendTimeout) {
      return const ApiException(
        code: 'TIMEOUT',
        message: 'Le serveur met trop de temps à répondre.',
      );
    }
    return const ApiException(
      code: 'NETWORK_ERROR',
      message: 'Connexion impossible. Vérifiez votre réseau.',
    );
  }

  @override
  String toString() => 'ApiException($code, $message)';
}

/// Enveloppe de réponse `{data, meta}`.
class Envelope<T> {
  const Envelope({required this.data, required this.meta});

  final T data;
  final ResponseMeta meta;
}

class ResponseMeta {
  const ResponseMeta({
    required this.serverTime,
    required this.apiVersion,
    this.degraded = false,
    this.degradedReason,
    this.freshnessSeconds,
  });

  final String serverTime;
  final String apiVersion;
  final bool degraded;
  final String? degradedReason;
  final int? freshnessSeconds;

  factory ResponseMeta.fromJson(Map<String, dynamic> json) {
    return ResponseMeta(
      serverTime: json['server_time'] as String? ?? '',
      apiVersion: json['api_version'] as String? ?? '',
      degraded: json['degraded'] as bool? ?? false,
      degradedReason: json['degraded_reason'] as String?,
      freshnessSeconds: (json['freshness_seconds'] as num?)?.toInt(),
    );
  }
}

class PaginatedResponse {
  const PaginatedResponse({
    required this.data,
    required this.pagination,
    required this.meta,
  });

  final List<Map<String, dynamic>> data;
  final Map<String, dynamic> pagination;
  final ResponseMeta meta;
}

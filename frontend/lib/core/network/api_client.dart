import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Tüm FastAPI Sunucu trafiğimizin kalbi.
/// Firebase ID Token otomatik olarak her isteğe eklenir.
class ApiClient {
  static Dio? _dio;

  /// Platform'a göre doğru base URL'i belirler:
  /// - Web: localhost
  /// - Android Emülatör: 10.0.2.2 (localhost yerine)
  /// - iOS Simulator / Fiziksel Cihaz: localhost
  static String get _baseUrl {
    const port = '8000';
    if (kIsWeb) {
      return 'http://127.0.0.1:$port/api/v1';
    }
    // Android emülatör 10.0.2.2 kullanır (host makinenin loopback adresi)
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:$port/api/v1';
      }
    } catch (_) {}
    return 'http://127.0.0.1:$port/api/v1';
  }

  static Dio get dio {
    _dio ??= _createDio();
    return _dio!;
  }

  static Dio _createDio() {
    final dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    dio.interceptors.add(_AuthInterceptor());
    
    // Debug modda istekleri logla
    if (kDebugMode) {
      dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => debugPrint('🌐 $obj'),
      ));
    }

    return dio;
  }
}

/// Firebase ID Token'ı otomatik olarak her isteğe ekleyen Interceptor.
/// Token expired olduğunda otomatik yenileme ve tekrar deneme yapar.
class _AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Firebase otomatik olarak süresi dolmuş token'ı yeniler (force: false)
        final token = await user.getIdToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
      }
    } catch (e) {
      debugPrint('⚠️ Firebase token alınamadı: $e');
    }
    return handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // 401 Unauthorized → Token süresi dolmuş olabilir, yenileme dene
    if (err.response?.statusCode == 401) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          // Token'ı zorla yenile
          final newToken = await user.getIdToken(true);
          if (newToken != null) {
            // İsteği yeni token ile tekrar dene
            final opts = err.requestOptions;
            opts.headers['Authorization'] = 'Bearer $newToken';
            
            final response = await Dio().fetch(opts);
            return handler.resolve(response);
          }
        }
      } catch (e) {
        debugPrint('⚠️ Token yenileme başarısız: $e');
      }
    }
    return handler.next(err);
  }
}

import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tüm FastAPI Sunucu trafiğimizin kalbi.
/// Firebase ID Token otomatik olarak her isteğe eklenir.
class ApiClient {
  static Dio? _dio;
  static String? _simpleAuthToken;

  static const String _tokenKey = 'simple_auth_token';

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

  /// Token'ı hem memory'de hem de SharedPreferences'ta saklar.
  /// Böylece sayfa yenilendiğinde (F5) token kaybolmaz.
  static Future<void> setSimpleAuthToken(String? token) async {
    _simpleAuthToken = token;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (token != null) {
        await prefs.setString(_tokenKey, token);
      } else {
        await prefs.remove(_tokenKey);
      }
    } catch (e) {
      debugPrint('⚠️ Token kaydedilemedi: $e');
    }
  }

  /// Token'ı temizler (logout işlemi için).
  static Future<void> clearSimpleAuthToken() async {
    _simpleAuthToken = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
    } catch (e) {
      debugPrint('⚠️ Token temizlenemedi: $e');
    }
  }

  /// Uygulama başlatıldığında SharedPreferences'tan token'ı geri yükler.
  static Future<void> restoreToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString(_tokenKey);
      if (savedToken != null && savedToken.isNotEmpty) {
        _simpleAuthToken = savedToken;
        debugPrint('🔑 Kaydedilmiş token geri yüklendi.');
      }
    } catch (e) {
      debugPrint('⚠️ Token geri yüklenemedi: $e');
    }
  }

  static String? get simpleAuthToken => _simpleAuthToken;

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
    // Önce simple auth token var mı kontrol et
    if (ApiClient.simpleAuthToken != null) {
      options.headers['Authorization'] = 'Bearer ${ApiClient.simpleAuthToken}';
      return handler.next(options);
    }

    // Yoksa Firebase token dene
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
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
      // Simple auth token ile 401 alırsan basit login'e yönlendir
      if (ApiClient.simpleAuthToken != null) {
        // Token yenilenemez, basit auth kullanıldığı için logout gerekebilir
        debugPrint('⚠️ Simple auth token expired');
      }

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final newToken = await user.getIdToken(true);
          if (newToken != null) {
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

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String _defaultBaseUrl = 'https://buyselladda.com/api';
  static Dio? _dio;

  static String get baseUrl {
    final configuredUrl = dotenv.env['BASE_URL']?.trim();
    final rawUrl =
        (configuredUrl == null || configuredUrl.isEmpty) ? _defaultBaseUrl : configuredUrl;

    final withoutTrailingSlash = rawUrl.endsWith('/')
        ? rawUrl.substring(0, rawUrl.length - 1)
        : rawUrl;

    return _normalizeBaseUrl(withoutTrailingSlash);
  }
  
  static Dio get instance {
    _dio ??= Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      validateStatus: (status) => status != null && status >= 200 && status < 400,
      headers: const {
        'Accept': 'application/json',
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
        'Expires': '0',
      },
    ));
    _dio!.options.baseUrl = baseUrl;

    // Interceptor for auth token
    _dio!.interceptors.clear();
    _dio!.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('token');
        if (token != null && token != 'undefined' && token != 'null' && token.trim().isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        options.headers.remove('If-None-Match');
        options.headers.remove('If-Modified-Since');
        handler.next(options);
      },
      onError: (error, handler) {
        handler.next(error);
      },
    ));
    
    return _dio!;
  }
  
  static Future<Response> post(String path, {dynamic data, FormData? formData}) async {
    return instance.post(path, data: formData ?? data);
  }
  
  static Future<Response> get(String path, {Map<String, dynamic>? query}) async {
    return instance.get(path, queryParameters: query);
  }
  
  static Future<Response> put(String path, {dynamic data}) async {
    return instance.put(path, data: data);
  }

  static Future<Response> patch(String path, {dynamic data}) async {
    return instance.patch(path, data: data);
  }
  
  static Future<Response> delete(String path) async {
    return instance.delete(path);
  }

  static String _normalizeBaseUrl(String rawUrl) {
    final withoutTrailingSlash = rawUrl.trim().endsWith('/')
        ? rawUrl.trim().substring(0, rawUrl.trim().length - 1)
        : rawUrl.trim();
    return withoutTrailingSlash.endsWith('/api')
        ? withoutTrailingSlash
        : '$withoutTrailingSlash/api';
  }
}

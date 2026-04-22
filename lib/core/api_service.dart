import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';

class ApiService {
  static Dio? _dio;
  
  static Dio get instance {
    _dio ??= Dio(BaseOptions(
      baseUrl: dotenv.env['BASE_URL'] ?? 'http://10.0.2.2:5000/api',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));
    
    // Interceptor for auth token
    _dio!.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer \$token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          // Handle unauthorized - logout
        }
        handler.next(error);
      },
    ));
    
    return _dio!;
  }
  
  static Future<Response> post(String path, {dynamic data, FormData? formData}) async {
    return instance.post(path, data: data ?? formData);
  }
  
  static Future<Response> get(String path, {Map<String, dynamic>? query}) async {
    return instance.get(path, queryParameters: query);
  }
  
  static Future<Response> put(String path, {dynamic data}) async {
    return instance.put(path, data: data);
  }
  
  static Future<Response> delete(String path) async {
    return instance.delete(path);
  }
}


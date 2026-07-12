import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'api_service.dart';
import 'constants.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

class AuthState {
  final User? user;
  final bool isLoading;
  final bool isAuthenticated;
  final bool hasChecked;
  final String? error;
  
  const AuthState({
    this.user,
    this.isLoading = false,
    this.isAuthenticated = false,
    this.hasChecked = false,
    this.error,
  });
  
  AuthState copyWith({
    User? user,
    bool? isLoading,
    bool? isAuthenticated,
    bool? hasChecked,
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      hasChecked: hasChecked ?? this.hasChecked,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());
  static const _tokenKey = 'token';
  static const _userKey = 'user';
  
  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await ApiService.post('${AppConstants.authPath}/login', 
        data: {'email': email, 'password': password});
      
      final payload = response.data['data'] ?? response.data;
      final token = payload['token'];
      final userData = payload['user'];
      
      await _persistSession(token, userData);

      state = AuthState(
        user: User.fromJson(userData),
        isAuthenticated: true,
        hasChecked: true,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _readError(e));
      rethrow;
    }
  }
  
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    state = const AuthState(hasChecked: true);
  }
  
  Future<String> register(String name, String email, String password, String phone, {String userType = 'normal'}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await ApiService.post('${AppConstants.authPath}/register', 
        data: {'name': name, 'email': email, 'password': password, 'phone': phone, 'userType': userType});
      state = state.copyWith(isLoading: false, error: null);
      return response.data['message']?.toString() ?? 'Please verify your email before login.';
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _readError(e));
      rethrow;
    }
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await ApiService.put('${AppConstants.userPath}/profile', data: data);
      final payload = response.data['data'] ?? response.data;
      final userData = payload['user'] ?? payload;
      await _persistUser(userData);
      state = AuthState(
        user: User.fromJson(userData),
        isAuthenticated: true,
        hasChecked: true,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _readError(e));
      rethrow;
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await ApiService.put(
        '${AppConstants.authPath}/change-password',
        data: {
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        },
      );
      state = state.copyWith(isLoading: false, error: null);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _readError(e));
      rethrow;
    }
  }

  Future<void> resetPassword({
    required String token,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await ApiService.put(
        '${AppConstants.authPath}/reset-password/$token',
        data: {'password': password},
      );
      final payload = response.data['data'] ?? response.data;
      final authToken = payload['token'];
      final userData = payload['user'];
      await _persistSession(authToken, userData);
      state = AuthState(
        user: User.fromJson(userData),
        isAuthenticated: true,
        hasChecked: true,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _readError(e));
      rethrow;
    }
  }
  
  Future<void> checkAuthStatus() async {
    if (state.hasChecked || state.isLoading) return;
    state = state.copyWith(isLoading: true, error: null);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token != null) {
      final cachedUser = _readCachedUser(prefs);
      if (cachedUser != null) {
        state = AuthState(user: cachedUser, isAuthenticated: true, hasChecked: false, isLoading: true);
      }
      try {
        final response = await ApiService.get('${AppConstants.userPath}/me');
        final payload = response.data['data'] ?? response.data;
        final userData = payload['user'] ?? payload;
        await _persistUser(userData);
        state = AuthState(
          user: User.fromJson(userData),
          isAuthenticated: true,
          hasChecked: true,
        );
      } catch (e) {
        if (cachedUser != null) {
          state = AuthState(
            user: cachedUser,
            isAuthenticated: true,
            hasChecked: true,
            error: null,
          );
        } else {
          state = const AuthState(hasChecked: true);
        }
      }
    } else {
      state = const AuthState(hasChecked: true);
    }
  }

  Future<void> _persistSession(dynamic token, dynamic userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, '$token');
    await _persistUser(userData);
  }

  Future<void> _persistUser(dynamic userData) async {
    if (userData is! Map) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(Map<String, dynamic>.from(userData)));
  }

  User? _readCachedUser(SharedPreferences prefs) {
    final raw = prefs.getString(_userKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final data = jsonDecode(raw);
      if (data is Map) return User.fromJson(Map<String, dynamic>.from(data));
    } catch (_) {}
    return null;
  }

  String _readError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['message'] != null) return '${data['message']}';
      return error.message ?? 'Something went wrong';
    }
    return error.toString();
  }
}


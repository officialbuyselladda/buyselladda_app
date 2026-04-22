import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'api_service.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

class AuthState {
  final User? user;
  final bool isLoading;
  final bool isAuthenticated;
  
  const AuthState({
    this.user,
    this.isLoading = false,
    this.isAuthenticated = false,
  });
  
  AuthState copyWith({User? user, bool? isLoading, bool? isAuthenticated}) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());
  
  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true);
    try {
      final response = await ApiService.post('${AppConstants.authPath}/login', 
        data: {'email': email, 'password': password});
      
      final token = response.data['token'];
      final userData = response.data['user'];
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);
      
      state = AuthState(
        user: User.fromJson(userData),
        isAuthenticated: true,
      );
    } catch (e) {
      // Handle error
      state = state.copyWith(isLoading: false);
    }
  }
  
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
      );
    }
  }
  
  Future<void> register(String name, String email, String password, String phone) async {
    state = state.copyWith(isLoading: true);
    try {
      final response = await ApiService.post('\${AppConstants.authPath}/register', 
        data: {'name': name, 'email': email, 'password': password, 'phone': phone});
      
      final token = response.data['token'];
      final userData = response.data['user'];
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);
      
      state = AuthState(
        user: User.fromJson(userData),
        isAuthenticated: true,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }
  
  Future<void> checkAuthStatus() async {

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token != null) {
      // Validate token by fetching /user/me
      try {
        final response = await ApiService.get('${AppConstants.userPath}/me');
        state = AuthState(
          user: User.fromJson(response.data),
          isAuthenticated: true,
        );
      } catch (e) {
        await logout();
      }
    }
  }
}


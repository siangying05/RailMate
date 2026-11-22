import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';

class RemoteException implements Exception {
  final String message;

  final String? code;

  const RemoteException(this.message, {this.code});

  RemoteException.from(AuthException error)
      : message = error.message,
        code = error.code;

  bool get isEmailNotConfirmed =>
      code == 'email_not_confirmed' ||
      message.toLowerCase().contains('email not confirmed');

  @override
  String toString() => message;
}

class SupabaseService {
  SupabaseService._();

  SupabaseService.stub();

  static final SupabaseService instance = SupabaseService._();

  bool _initialised = false;
  bool _available = false;

  bool get isAvailable => _available;

  SupabaseClient get _client => Supabase.instance.client;

  Future<void> initialise() async {
    if (_initialised) return;
    _initialised = true;

    if (!SupabaseConfig.enabled) {
      _available = false;
      return;
    }

    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.publishableKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
      ).timeout(const Duration(seconds: 8));
      _available = true;
    } on TimeoutException {
      _available = false;
    } catch (_) {
      _available = false;
    }
  }

  User? get currentUser => _available ? _client.auth.currentUser : null;

  Session? get currentSession => _available ? _client.auth.currentSession : null;

  Stream<AuthState> get authChanges =>
      _available ? _client.auth.onAuthStateChange : const Stream.empty();

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required Map<String, dynamic> metadata,
  }) async {
    _requireAvailable();
    try {
      return await _client.auth.signUp(
        email: email,
        password: password,
        data: metadata,
      );
    } catch (error) {
      _asRemote(error);
    }
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    _requireAvailable();
    try {
      return await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (error) {
      _asRemote(error);
    }
  }

  Future<void> resendSignupCode(String email) async {
    _requireAvailable();
    try {
      await _client.auth.resend(email: email, type: OtpType.signup);
    } catch (error) {
      _asRemote(error);
    }
  }

  Future<AuthResponse> verifyOtp({
    required String email,
    required String token,
    OtpType type = OtpType.email,
  }) async {
    _requireAvailable();
    try {
      return await _client.auth.verifyOTP(
        email: email,
        token: token,
        type: type,
      );
    } catch (error) {
      _asRemote(error);
    }
  }

  Future<void> resetPassword(String email) async {
    _requireAvailable();
    try {
      await _client.auth.resetPasswordForEmail(email);
    } catch (error) {
      _asRemote(error);
    }
  }

  Future<void> updatePassword(String newPassword) async {
    _requireAvailable();
    try {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
    } catch (error) {
      _asRemote(error);
    }
  }

  Future<void> signOut() async {
    if (!_available) return;
    await _client.auth.signOut();
  }

  Future<void> upsert(String table, Map<String, dynamic> row) async {
    _requireAvailable();
    try {
      await _client.from(table).upsert(row);
    } catch (error) {
      _asRemote(error);
    }
  }

  Future<void> deleteWhere(
    String table,
    Map<String, dynamic> filters,
  ) async {
    _requireAvailable();
    try {
      var query = _client.from(table).delete();
      filters.forEach((column, value) {
        query = query.eq(column, value);
      });
      await query;
    } catch (error) {
      _asRemote(error);
    }
  }

  Future<List<Map<String, dynamic>>> select(
    String table, {
    Map<String, dynamic> filters = const {},
    String? orderBy,
    bool ascending = false,
  }) async {
    _requireAvailable();
    try {
      var query = _client.from(table).select();
      filters.forEach((column, value) {
        query = query.eq(column, value);
      });

      final response = orderBy == null
          ? await query
          : await query.order(orderBy, ascending: ascending);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (error) {
      _asRemote(error);
    }
  }

  Never _asRemote(Object error) {
    if (error is RemoteException) throw error;
    if (error is AuthException) throw RemoteException.from(error);
    if (error is PostgrestException) {
      throw RemoteException(error.message, code: error.code);
    }
    throw const RemoteException(
      'RailMate could not reach the server. Check your connection and try again.',
      code: 'network_error',
    );
  }

  void _requireAvailable() {
    if (!_available) {
      throw const RemoteException(
        'RailMate is running offline. This action needs an internet connection.',
      );
    }
  }
}

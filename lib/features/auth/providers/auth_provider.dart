import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/config/supabase_config.dart';
import '../../../core/providers/safe_notifier.dart';
import '../../../data/datasources/remote/supabase_service.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../data/repositories/sync_queue.dart';

enum AuthStage { checking, signedOut, awaitingOtp, signedIn }

class AuthProvider extends SafeNotifier {
  final SupabaseService _remote;
  final ProfileRepository _profiles;
  final SyncQueue _syncQueue;

  AuthProvider({
    SupabaseService? remote,
    ProfileRepository? profiles,
    SyncQueue? syncQueue,
  })  : _remote = remote ?? SupabaseService.instance,
        _profiles = profiles ?? ProfileRepository(),
        _syncQueue = syncQueue ?? SyncQueue();

  AuthStage _stage = AuthStage.checking;
  UserProfile _profile = UserProfile.guest();
  String? _error;
  String? _notice;
  bool _busy = false;
  String _pendingEmail = '';
  int _pendingSyncCount = 0;
  int _abandonedSyncCount = 0;

  AuthStage get stage => _stage;
  UserProfile get profile => _profile;
  String? get error => _error;
  String? get notice => _notice;
  bool get busy => _busy;
  String get pendingEmail => _pendingEmail;
  int get pendingSyncCount => _pendingSyncCount;
  int get abandonedSyncCount => _abandonedSyncCount;

  int get unsyncedCount => _pendingSyncCount + _abandonedSyncCount;

  bool get isSignedIn => _stage == AuthStage.signedIn;
  bool get isGuest => _profile.isGuest;
  bool get remoteAvailable => _remote.isAvailable;

  Future<void> bootstrap() async {
    _stage = AuthStage.checking;
    notifyListeners();

    final user = _remote.currentUser;
    if (user != null) {
      _profile = await _profiles.resolve(
        userId: user.id,
        email: user.email ?? '',
        fullName: (user.userMetadata?['full_name'] as String?) ?? 'Commuter',
      );
      _stage = AuthStage.signedIn;
    } else {
      _profile = UserProfile.guest();
      _stage = AuthStage.signedOut;
    }

    await refreshSyncCount();
    notifyListeners();
  }

  Future<bool> register({
    required String fullName,
    required String email,
    required String mobile,
    required String password,
    required PassengerType passengerType,
  }) async {
    return _run(() async {
      final response = await _remote.signUp(
        email: email,
        password: password,
        metadata: {
          'full_name': fullName,
          'mobile': mobile,
          'passenger_type': passengerType.name,
        },
      );

      _pendingEmail = email;

      if (response.session != null && response.user != null) {
        await _completeSignIn(
          response.user!,
          fullName: fullName,
          mobile: mobile,
          passengerType: passengerType,
        );
        return true;
      }

      _stage = AuthStage.awaitingOtp;
      _notice =
          'We sent a verification code to $email. Enter it below to finish setting up your account.';
      return true;
    });
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    return _run(() async {
      final sb.AuthResponse response;
      try {
        response = await _remote.signIn(email: email, password: password);
      } on RemoteException catch (exception) {
        if (!exception.isEmailNotConfirmed) rethrow;
        _pendingEmail = email;
        _stage = AuthStage.awaitingOtp;
        await _remote.resendSignupCode(email);
        _notice = 'Verify $email first. A new code is on its way.';
        return true;
      }

      final user = response.user;
      if (user == null) {
        _error = 'Sign in failed. Please try again.';
        return false;
      }
      await _completeSignIn(user);
      return true;
    });
  }

  Future<bool> verifyOtp(String token) async {
    return _run(() async {
      final response = await _remote.verifyOtp(
        email: _pendingEmail,
        token: token,
        type: sb.OtpType.signup,
      );
      final user = response.user;
      if (user == null) {
        _error = 'That code did not match. Request a new one and try again.';
        return false;
      }
      await _completeSignIn(user);
      return true;
    });
  }

  Future<bool> resendOtp() async {
    return _run(() async {
      await _remote.resendSignupCode(_pendingEmail);
      _notice = 'A new code is on its way to $_pendingEmail.';
      return true;
    });
  }

  Future<bool> sendPasswordReset(String email) async {
    return _run(() async {
      await _remote.resetPassword(email);
      _notice = 'Password reset instructions have been sent to $email.';
      return true;
    });
  }

  /// Lets a signed-in user set a new password from inside the app, without
  /// leaving to click an emailed reset link (which [sendPasswordReset]
  /// still exists for, e.g. a forgotten password while signed out).
  Future<bool> changePassword(String newPassword) async {
    return _run(() async {
      await _remote.updatePassword(newPassword);
      _notice = 'Your password has been updated.';
      return true;
    });
  }

  /// Deletes the RailMate profile row (and any locally cached copy) and
  /// signs the user out. Supabase does not allow an app running with only
  /// the publishable client key to delete the underlying `auth.users` row -
  /// that needs the service-role key, which must never ship inside a
  /// mobile app - so this is a best-effort "erase what we can reach"
  /// rather than a full account deletion. The notice below says so.
  Future<bool> deleteAccount() async {
    return _run(() async {
      if (_profile.isGuest) {
        _error = 'Guest sessions have nothing to delete.';
        return false;
      }

      final userId = _profile.id;
      await _profiles.deleteLocal(userId);

      try {
        if (_remote.isAvailable) {
          await _remote.deleteWhere(SupabaseConfig.tableProfiles, {
            'id': userId,
          });
        }
      } on RemoteException {
        // Best effort: row level security already scopes this row to a
        // user who is about to be signed out, so a failed delete here
        // doesn't expose anything - it just leaves an orphaned row behind.
      }

      await _remote.signOut();
      _profile = UserProfile.guest();
      _stage = AuthStage.signedOut;
      _pendingEmail = '';
      _notice = 'Your RailMate profile has been deleted. For security, '
          'the app cannot remove the underlying login credentials itself - '
          'contact support if you need the account itself erased too.';
      return true;
    });
  }

  Future<void> continueAsGuest() async {
    _profile = UserProfile.guest();
    await _profiles.saveLocal(_profile);
    _stage = AuthStage.signedIn;
    _notice =
        'You are browsing as a guest. Sign in to sync favourites and buy tickets.';
    notifyListeners();
  }

  Future<void> signOut() async {
    await _remote.signOut();
    _profile = UserProfile.guest();
    _stage = AuthStage.signedOut;
    _pendingEmail = '';
    _error = null;
    _notice = null;
    notifyListeners();
  }

  Future<void> updateProfile(UserProfile updated) async {
    _profile = await _profiles.save(updated);
    await refreshSyncCount();
    notifyListeners();
  }

  Future<void> setPreference(RoutePreference preference) async {
    await updateProfile(_profile.copyWith(preference: preference));
  }

  Future<void> setPassengerType(PassengerType type) async {
    await updateProfile(_profile.copyWith(passengerType: type));
  }

  Future<void> refreshSyncCount() async {
    _pendingSyncCount = await _syncQueue.pendingCount();
    _abandonedSyncCount = await _syncQueue.abandonedCount();
    notifyListeners();
  }

  Future<SyncResult> syncNow() async {
    await _syncQueue.retryAbandoned();
    final result = await _syncQueue.drain();
    await refreshSyncCount();
    return result;
  }

  void clearMessages() {
    _error = null;
    _notice = null;
    notifyListeners();
  }

  void backToSignIn() {
    _stage = AuthStage.signedOut;
    _error = null;
    notifyListeners();
  }

  Future<void> _completeSignIn(
    sb.User user, {
    String? fullName,
    String? mobile,
    PassengerType? passengerType,
  }) async {
    var resolved = await _profiles.resolve(
      userId: user.id,
      email: user.email ?? _pendingEmail,
      fullName: fullName ??
          (user.userMetadata?['full_name'] as String?) ??
          'Commuter',
    );

    if (fullName != null || mobile != null || passengerType != null) {
      resolved = resolved.copyWith(
        fullName: fullName,
        mobile: mobile,
        passengerType: passengerType,
      );
      resolved = await _profiles.save(resolved);
    }

    _profile = resolved;
    _stage = AuthStage.signedIn;
    _error = null;
    _notice = null;

    await _syncQueue.drain();
    await refreshSyncCount();
  }

  Future<bool> _run(Future<bool> Function() action) async {
    _busy = true;
    _error = null;
    _notice = null;
    notifyListeners();

    var success = false;
    try {
      success = await action();
    } on RemoteException catch (exception) {
      _error = exception.message;
    } catch (exception) {
      _error = 'Something went wrong. Please try again.';
    }

    _busy = false;
    notifyListeners();
    return success;
  }
}

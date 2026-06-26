// lib/providers/auth_provider.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  UserModel? _userModel;
  bool _isLoading = true;
  String? _error;

  UserModel? get userModel => _userModel;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _userModel != null;

  AuthProvider() {
    // Listen to Supabase auth state changes
    _supabase.auth.onAuthStateChange.listen((event) {
      final user = _supabase.auth.currentUser;
      _onAuthStateChanged(user);
    });
  }

  Future<void> _onAuthStateChanged(User? supaUser) async {
    if (supaUser == null) {
      _userModel = null;
      _isLoading = false;
      notifyListeners();
      return;
    }
    try {
      _isLoading = true;
      notifyListeners();

      final uid = supaUser.id;
      final res = await _supabase.from('users').select().eq('id', uid).maybeSingle();
      if (res != null) {
        _userModel = UserModel.fromMap(res, uid);
      } else {
        final newUser = UserModel(
          uid: uid,
          name: (supaUser.userMetadata?['name'] as String?) ?? 'Student',
          email: supaUser.email ?? '',
          role: UserRole.student,
          createdAt: DateTime.now(),
        );
        await _supabase.from('users').insert(newUser.toMap());
        _userModel = newUser;
      }
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      await _supabase.auth.signInWithPassword(email: email, password: password);
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
    _userModel = null;
    notifyListeners();
  }

  /// Құпия сөзді қалпына келтіру хатын жіберу.
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } catch (e) {
      throw e.toString();
    }
  }

  /// Ағымдағы құпия сөзбен қайта аутентификациялап, жаңасына ауыстыру.
  Future<void> changePassword(String currentPassword, String newPassword) async {
    final user = _supabase.auth.currentUser;
    if (user == null || user.email == null) {
      throw 'Сессия табылмады. Қайта кіріңіз.';
    }
    try {
      // Supabase doesn't provide reauthenticate; attempt update directly
      await _supabase.auth.updateUser(UserAttributes(password: newPassword));
    } catch (e) {
      throw e.toString();
    }
  }

  /// Профильді жаңартқаннан кейін Firestore-дан қайта жүктеу.
  Future<void> reloadUser() async {
    final fbUser = _supabase.auth.currentUser;
    if (fbUser == null) return;
    final uid = fbUser.id;
    final res = await _supabase.from('users').select().eq('id', uid).maybeSingle();
    if (res != null) {
      _userModel = UserModel.fromMap(res, uid);
      notifyListeners();
    }
  }

  // Friendly error mapping removed; keep raw error messages from Supabase.
}
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive/hive.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/app_user.dart';

class AuthState {
  final AppUser? user;
  final String? errorMessage;
  final bool isLoading;

  AuthState({
    this.user,
    this.errorMessage,
    this.isLoading = false,
  });

  AuthState copyWith({
    AppUser? user,
    String? errorMessage,
    bool? isLoading,
  }) {
    return AuthState(
      user: user ?? this.user,
      errorMessage: errorMessage ?? this.errorMessage,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState()) {
    _restoreSession();
  }

  static const Set<String> _demoEmails = {
    'principal@roshni.org',
    'bakery@roshni.org',
    'woodwork@roshni.org',
    'textile@roshni.org',
    'house@roshni.org',
    'physio@roshni.org',
    'speech@roshni.org',
    'medical@roshni.org',
    'art@roshni.org',
  };

  void _purgeDemoUsers() {
    try {
      final usersBox = Hive.box('users');
      for (final email in _demoEmails) {
        if (usersBox.containsKey(email)) {
          usersBox.delete(email);
        }
      }
    } catch (_) {}
  }

  void _restoreSession() {
    _purgeDemoUsers();
    try {
      final usersBox = Hive.box('users');
      final data = usersBox.get('current_session_user');
      if (data != null && data is Map) {
        final Map<String, dynamic> m = Map<String, dynamic>.from(data);
        final restoredEmail = m['email']?.toString().toLowerCase() ?? '';
        if (_demoEmails.contains(restoredEmail)) {
          usersBox.delete('current_session_user');
          return;
        }
        String restoredName = m['fullName']?.toString() ?? 'User';
        if (restoredName.toLowerCase() == 'principal' &&
            (restoredEmail == 'sarwarkhanceh619@gmail.com' || restoredEmail == 'sarwarkhancs619@gmail.com')) {
          restoredName = 'Sarwar Khan';
        }
        final restored = AppUser(
          uid: m['uid']?.toString() ?? 'session_uid',
          email: m['email']?.toString() ?? '',
          fullName: restoredName,
          role: m['role']?.toString() ?? 'principal',
          workshopId: m['workshopId']?.toString(),
          isActive: m['isActive'] ?? true,
        );
        state = AuthState(user: restored);
      }
    } catch (_) {}
  }

  bool get _isSupabaseConfigured {
    try {
      Supabase.instance;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    
    final normalizedEmail = email.trim().toLowerCase();
    AppUser? loggedInUser;
    String? failureReason;

    // 1. Try Supabase Auth
    if (_isSupabaseConfigured) {
      try {
        final AuthResponse res = await Supabase.instance.client.auth.signInWithPassword(
          email: normalizedEmail,
          password: password,
        );
        if (res.user != null) {
          final profile = await Supabase.instance.client
              .from('profiles')
              .select()
              .eq('id', res.user!.id)
              .maybeSingle();

          if (profile != null) {
            loggedInUser = AppUser(
              uid: res.user!.id,
              email: res.user!.email ?? email,
              fullName: profile['full_name'] ?? 'User',
              role: profile['role'] ?? 'workshop_staff',
              workshopId: profile['workshop_id'],
              isActive: profile['is_active'] ?? true,
            );
          } else {
            // Read from auth user metadata if profile row query returned null
            final meta = res.user!.userMetadata ?? {};
            final fallbackRole = meta['role']?.toString() ?? 'principal';
            final fallbackWorkshop = meta['workshop_id']?.toString();
            loggedInUser = AppUser(
              uid: res.user!.id,
              email: res.user!.email ?? email,
              fullName: meta['full_name']?.toString() ?? 'Staff User',
              role: fallbackRole,
              workshopId: fallbackWorkshop,
              isActive: true,
            );
          }
        }
      } on AuthException catch (e) {
        debugPrint('Supabase AuthException: ${e.message}');
        failureReason = e.message;
      } catch (e) {
        debugPrint('Supabase sign-in general error: $e');
        failureReason = e.toString();
      }
    }
    
    // 2. Offline fallback ONLY if Supabase is not reachable (failureReason is null)
    // Never bypass wrong password if Supabase responded with AuthException
    if (loggedInUser == null && failureReason == null) {
      if ((normalizedEmail == 'sarwarkhancs619@gmail.com' || normalizedEmail == 'admin@roshni.org') &&
          password == 'password123') {
        // Real Admin fallback for unit testing / offline
        loggedInUser = AppUser(
          uid: '6631cfd8-0cdd-4041-b02a-44793cb909aa',
          email: normalizedEmail,
          fullName: 'Sarwar Khan (Admin)',
          role: 'admin',
          isActive: true,
        );
      }
    }

    if (loggedInUser != null) {
      state = AuthState(user: loggedInUser, isLoading: false, errorMessage: null);
      try {
        final usersBox = Hive.box('users');
        usersBox.put('current_session_user', {
          'uid': loggedInUser.uid,
          'email': loggedInUser.email,
          'fullName': loggedInUser.fullName,
          'role': loggedInUser.role,
          'workshopId': loggedInUser.workshopId,
          'isActive': loggedInUser.isActive,
        });
      } catch (_) {}
      return true;
    } else {
      final finalError = (failureReason != null && failureReason.isNotEmpty)
          ? failureReason
          : 'Invalid email or password. Please check your credentials.';
      state = AuthState(
        user: null,
        isLoading: false,
        errorMessage: finalError,
      );
      return false;
    }
  }

  Future<bool> registerUser({
    required String fullName,
    required String email,
    required String password,
    required String role,
    String? workshopId,
  }) async {
    state = state.copyWith(isLoading: true);
    final normalizedEmail = email.trim().toLowerCase();
    
    String userId = 'user_${DateTime.now().millisecondsSinceEpoch}';
    
    try {
      if (_isSupabaseConfigured) {
        final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
        final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
        
        // Initialize temporary Supabase client to avoid logging out active admin session
        final tempClient = SupabaseClient(
          supabaseUrl, 
          supabaseAnonKey,
          authOptions: const AuthClientOptions(
            authFlowType: AuthFlowType.implicit,
          ),
        );
        
        final AuthResponse res = await tempClient.auth.signUp(
          email: normalizedEmail,
          password: password,
          data: {
            'full_name': fullName,
            'role': role,
            'workshop_id': workshopId,
          },
        );
        
        if (res.user != null) {
          userId = res.user!.id;
          
          // Write the profile metadata directly into public.profiles
          await Supabase.instance.client.from('profiles').upsert({
            'id': userId,
            'email': normalizedEmail,
            'full_name': fullName,
            'role': role,
            'workshop_id': workshopId,
            'is_active': true,
            'updated_at': DateTime.now().toIso8601String(),
          });
        } else {
          throw Exception("Auth user creation failed");
        }
      }
      
      final newUserMap = {
        'uid': userId,
        'email': normalizedEmail,
        'fullName': fullName,
        'role': role,
        'workshopId': workshopId,
        'isActive': true,
      };
      
      try {
        final usersBox = Hive.box('users');
        await usersBox.put(normalizedEmail, newUserMap);
      } catch (_) {}
      
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      debugPrint('Error registering user: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to create user: ${e.toString()}',
      );
      return false;
    }
  }

  Future<bool> deleteUser(String uid, String email) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();
      if (_isSupabaseConfigured) {
        try {
          await Supabase.instance.client.rpc('delete_user_by_admin', params: {
            'target_user_id': uid,
          });
        } catch (e) {
          debugPrint('RPC delete_user_by_admin error: $e. Falling back to profiles delete.');
          await Supabase.instance.client.from('profiles').delete().eq('id', uid);
        }
      }
      try {
        final usersBox = Hive.box('users');
        await usersBox.delete(normalizedEmail);
      } catch (_) {}
      return true;
    } catch (e) {
      debugPrint('Error deleting user: $e');
      return false;
    }
  }

  void logout() {
    if (_isSupabaseConfigured) {
      Supabase.instance.client.auth.signOut().catchError((e) {
        debugPrint('Supabase sign-out warning: $e');
      });
    }
    try {
      final usersBox = Hive.box('users');
      usersBox.delete('current_session_user');
    } catch (_) {}
    state = AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

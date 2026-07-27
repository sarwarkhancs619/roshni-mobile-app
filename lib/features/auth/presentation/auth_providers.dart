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
  AuthNotifier() : super(AuthState());

  bool get _isSupabaseConfigured {
    try {
      Supabase.instance;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true);
    
    final normalizedEmail = email.trim().toLowerCase();
    AppUser? loggedInUser;

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
            // Default user fallback if profile row not created yet
            loggedInUser = AppUser(
              uid: res.user!.id,
              email: res.user!.email ?? email,
              fullName: 'Supabase User',
              role: 'workshop_staff',
              workshopId: 'bakery',
              isActive: true,
            );
          }
        }
      } catch (e) {
        debugPrint('Supabase sign-in failed, trying local offline fallback: $e');
      }
    }
    
    // 2. Local fallback mock logins
    if (loggedInUser == null) {
      dynamic storedUser;
      try {
        final usersBox = Hive.box('users');
        storedUser = usersBox.get(normalizedEmail);
      } catch (_) {
        // Safe fallback for unit tests where Hive boxes are not pre-opened
      }
      if (storedUser != null) {
        final Map<String, dynamic> userData = Map<String, dynamic>.from(storedUser);
        loggedInUser = AppUser(
          uid: userData['uid'] ?? 'custom_uid',
          email: userData['email'] ?? email,
          fullName: userData['fullName'] ?? 'Custom User',
          role: userData['role'] ?? 'workshop_staff',
          workshopId: userData['workshopId'],
          isActive: userData['isActive'] ?? true,
        );
      } else if (normalizedEmail == 'principal@roshni.org') {
        loggedInUser = AppUser(
          uid: 'principal_uid',
          email: email,
          fullName: 'Tariq Alvi (Principal)',
          role: 'principal',
          isActive: true,
        );
      } else if (normalizedEmail == 'admin@roshni.org') {
        loggedInUser = AppUser(
          uid: 'admin_uid',
          email: email,
          fullName: 'Zahid Khan (Admin)',
          role: 'admin',
          isActive: true,
        );
      } else if (normalizedEmail == 'bakery@roshni.org') {
        loggedInUser = AppUser(
          uid: 'bakery_staff_uid',
          email: email,
          fullName: 'Fatima Ali (Bakery Staff)',
          role: 'workshop_staff',
          workshopId: 'bakery',
          isActive: true,
        );
      } else if (normalizedEmail == 'woodwork@roshni.org') {
        loggedInUser = AppUser(
          uid: 'woodwork_staff_uid',
          email: email,
          fullName: 'Muhammad Ahmad (Woodwork Staff)',
          role: 'workshop_staff',
          workshopId: 'woodwork',
          isActive: true,
        );
      } else if (normalizedEmail == 'textile@roshni.org') {
        loggedInUser = AppUser(
          uid: 'textile_staff_uid',
          email: email,
          fullName: 'Sobia Imran (Textile Staff)',
          role: 'workshop_staff',
          workshopId: 'textile',
          isActive: true,
        );
      } else if (normalizedEmail == 'house@roshni.org') {
        loggedInUser = AppUser(
          uid: 'house_staff_uid',
          email: email,
          fullName: 'Asia Bibi (House Mother)',
          role: 'house_staff',
          workshopId: 'amin_house',
          isActive: true,
        );
      } else if (normalizedEmail == 'physio@roshni.org') {
        loggedInUser = AppUser(
          uid: 'physio_uid',
          email: email,
          fullName: 'Dr. Sarah Smith (Physiotherapist)',
          role: 'physiotherapist',
          isActive: true,
        );
      } else if (normalizedEmail == 'speech@roshni.org') {
        loggedInUser = AppUser(
          uid: 'speech_uid',
          email: email,
          fullName: 'Amina Shah (Speech Therapist)',
          role: 'speech_therapist',
          isActive: true,
        );
      } else if (normalizedEmail == 'medical@roshni.org') {
        loggedInUser = AppUser(
          uid: 'medical_uid',
          email: email,
          fullName: 'Dr. Usman Ahmed (Medical Officer)',
          role: 'medical_officer',
          isActive: true,
        );
      }
    }

    if (loggedInUser != null) {
      state = AuthState(user: loggedInUser);
      return true;
    } else {
      state = AuthState(
        errorMessage: 'Invalid username or password. Try admin@roshni.org, bakery@roshni.org, or your Supabase credentials.',
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
        );
        
        if (res.user != null) {
          userId = res.user!.id;
          
          // Write the profile metadata directly into public.profiles
          await Supabase.instance.client.from('profiles').insert({
            'id': userId,
            'email': normalizedEmail,
            'full_name': fullName,
            'role': role,
            'workshop_id': workshopId,
            'is_active': true,
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
      
      final usersBox = Hive.box('users');
      await usersBox.put(normalizedEmail, newUserMap);
      
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

  void logout() {
    if (_isSupabaseConfigured) {
      Supabase.instance.client.auth.signOut().catchError((e) {
        debugPrint('Supabase sign-out warning: $e');
      });
    }
    state = AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

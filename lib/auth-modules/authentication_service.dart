import 'package:bcrypt/bcrypt.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthenticationService {
  final SupabaseClient client = Supabase.instance.client;

  // Sign out the user
  Future<void> signOut() async {
    await client.auth.signOut();
    await GoogleSignIn().signOut();
    await removeUserData();
  }

  // Sign in with Google
  Future<AuthResponse> signInWithGoogle() async {
    const String webClientId = '668392997039-f3si06im0efivfov2iptpt638uumi4q9.apps.googleusercontent.com';

    final GoogleSignIn googleSignIn = GoogleSignIn(
      serverClientId: webClientId,
    );

    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      throw AuthException('Google Sign-In aborted by user');
    }

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;

    if (idToken == null || accessToken == null) {
      throw AuthException('Google Sign-In failed');
    }

    final response = await client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );

    if (response.user != null) {
      await saveUserData(response.user!.id, googleUser.displayName, googleUser.email);
    }

    return response;
  }

  Future<Map<String, dynamic>?> signInWithUsernameAndPassword(String username, String password) async {
    final response = await client
        .from('users')
        .select()
        .eq('username', username)
        .single();

    if (response['error'] == null && response.isNotEmpty) {
      final user = response;
      if (BCrypt.checkpw(password, user['password'])) {
        await saveUserData(user['id'], user['fName'], user['email']);
        return user;
      } else {
        throw AuthException('Invalid password');
      }
    } else {
      throw AuthException(response['error']?.message ?? 'User not found');
    }
  }

  Future<void> saveUserData(String userId, String? name, String email) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('userId', userId);
    prefs.setString('userName', name ?? 'User');
    prefs.setString('userEmail', email);
  }

  Future<Map<String, String>?> getUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('userId');
    String? userName = prefs.getString('userName');
    String? userEmail = prefs.getString('userEmail');
    if (userId != null && userName != null && userEmail != null) {
      return {
        'userId': userId,
        'userName': userName,
        'userEmail': userEmail,
      };
    }
    return null;
  }

  Future<void> removeUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.remove('userId');
    prefs.remove('userName');
    prefs.remove('userEmail');
  }

  bool isAuthenticated() {
    return client.auth.currentUser != null;
  }

  Future<Map<String, String>?> loadSavedCredentials() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('rememberMe') ?? false) {
      return {
        'username': prefs.getString('username') ?? '',
        'password': prefs.getString('password') ?? '',
      };
    }
    return null;
  }

  Future<void> saveCredentials(String username, String password) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool('rememberMe', true);
    prefs.setString('username', username);
    prefs.setString('password', password);
  }

  Future<void> removeCredentials() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.remove('rememberMe');
    prefs.remove('username');
    prefs.remove('password');
  }
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => 'AuthException: $message';
}

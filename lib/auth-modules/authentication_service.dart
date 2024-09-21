import 'package:bcrypt/bcrypt.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthenticationService {
  final SupabaseClient client = Supabase.instance.client;

  // Insert a record of login activity
  Future<void> logLoginActivity(String userId) async {
    await client.from('login_activity').insert({
      'user_id': userId,
      'login_time': DateTime.now().toIso8601String(),
    });
  }

  // Update the last login timestamp for a user and log the activity
  Future<void> updateLastLogin(String userId, String tableName) async {
    await client
        .from(tableName)  // Can be 'users' or 'admin_users'
        .update({'last_login': DateTime.now().toIso8601String()})
        .eq('id', userId);

    await logLoginActivity(userId);  // Log the login activity
  }

  // Sign in with Username or Email and Password
// Sign in with Username or Email and Password
Future<Map<String, dynamic>?> signInWithUsernameOrEmailAndPassword(String input, String password) async {
  try {
    var response = await client
        .from('user_admin') 
        .select()
        .or('email.eq.$input,username.eq.$input')
        .limit(1)
        .single();  

    if (response == null) {
      throw AuthException('User not found with this email or username');
    }

    final user = response;

    if (BCrypt.checkpw(password, user['password'])) {
      await saveUserData(user['id'], user['fname'] ?? user['username'], user['email']);
      
      await updateLastLogin(user['id'], 'user_admin');

      return user;
    } else {
      throw AuthException('Invalid password');
    }
  } catch (error) {
    if (error is PostgrestException && error.code == 'PGRST116') {
      throw AuthException('No matching user found or multiple results returned');
    } else {
      throw AuthException('Unexpected error: $error');
    }
  }
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


  // Sign out the user
  Future<void> signOut() async {
    await client.auth.signOut();
    await GoogleSignIn().signOut();
    await removeUserData();
  }

  // User Management Methods
  // -----------------------

  // Update Password
  Future<void> updatePassword(String userId, String newPassword, String tableName) async {
    // Hash the new password
    final hashedPassword = BCrypt.hashpw(newPassword, BCrypt.gensalt());

    // Update the user's password in the appropriate table
    final response = await client
        .from(tableName)  // Either 'users' or 'admin_users'
        .update({'password': hashedPassword})
        .eq('id', userId);

    if (response.error != null) {
      throw AuthException('Failed to update password: ${response.error!.message}');
    }
  }

  // Get the current user's ID
  String? getCurrentUserId() {
    return client.auth.currentUser?.id;
  }

  // Delete the user's account
  Future<void> deleteUser(String tableName) async {
    final userId = getCurrentUserId();
    if (userId != null) {
      final response = await client
          .from(tableName)  // Either 'users' or 'admin_users'
          .delete()
          .eq('id', userId);

      if (response.error != null) {
        throw AuthException('Failed to delete user: ${response.error!.message}');
      } else {
        await signOut();
      }
    } else {
      throw AuthException('No user is currently signed in.');
    }
  }

  // Delete tracking data for a user
  Future<void> deleteTrackingData(String userId) async {
    final response = await client
        .from('emotion_tracking')
        .delete()
        .eq('user_id', userId);

    if (response != null) {
      throw AuthException('Failed to delete tracking data: ${response.error!.message}');
    }
  }

  // User Data Management Methods
  // ----------------------------

  // Save user data locally
  Future<void> saveUserData(String userId, String? name, String email) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('userId', userId);
    prefs.setString('userName', name ?? 'User');
    prefs.setString('userEmail', email);
  }

  // Get user data from local storage
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

  // Remove user data from local storage
  Future<void> removeUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.remove('userId');
    prefs.remove('userName');
    prefs.remove('userEmail');
  }

  // Authentication Status Methods
  // -----------------------------

  // Check if the user is authenticated
  bool isAuthenticated() {
    return client.auth.currentUser != null;
  }

  // Credential Management Methods
  // -----------------------------

  // Load saved credentials
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

  // Save credentials for future logins
  Future<void> saveCredentials(String username, String password) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool('rememberMe', true);
    prefs.setString('username', username);
    prefs.setString('password', password);
  }

  // Remove saved credentials
  Future<void> removeCredentials() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.remove('rememberMe');
    prefs.remove('username');
    prefs.remove('password');
  }
}

// Custom Exception Class for Authentication Errors
class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => 'AuthException: $message';
}
